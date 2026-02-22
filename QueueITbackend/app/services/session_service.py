from __future__ import annotations

from typing import Optional, Dict, Any, List
from fastapi import HTTPException, status

from app.core.auth import AuthenticatedClient
from app.repositories import SessionRepository, UserRepository, QueueRepository, SongRepository
from app.schemas.session import (
    SessionCreateRequest,
    SessionJoinRequest,
    SessionControlRequest,
    SessionBase,
    CurrentSessionResponse,
    QueuedSongResponse,
)
from app.schemas.user import User
from app.schemas.track import TrackOut


def _map_queue_item_to_schema(item: Dict[str, Any]) -> QueuedSongResponse:
    """
    Maps an enriched queue item (from QueueRepository.list_session_queue) into QueuedSongResponse.
    """
    track = TrackOut(
        external_id=item["song"]["external_id"],
        isrc_identifier=item["song"]["isrc_identifier"],
        name=item["song"]["name"],
        artist=item["song"]["artist"],
        album=item["song"]["album"],
        durationMSs=item["song"]["durationMSs"],
        image_url=item["song"]["image_url"],
    )
    added_by = User(id=item["added_by"]["id"], username=item["added_by"].get("username"))
    return QueuedSongResponse(
        id=item["id"],
        status=item["status"],
        added_at=item["added_at"],
        votes=int(item["votes"]),
        song=track,
        added_by=added_by,
    )


def _map_session_to_schema(session_row: Dict[str, Any], host_row: Dict[str, Any]) -> SessionBase:
    return SessionBase(
        id=session_row["id"],
        join_code=session_row["join_code"],
        created_at=session_row["created_at"],
        host=User(id=host_row["id"], username=host_row.get("username")),
    )


def get_current_session_for_user(auth: AuthenticatedClient) -> CurrentSessionResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)
    queue_repo = QueueRepository(client)

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        raise HTTPException(status_code=404, detail="No active session")

    host_row = user_repo.get_by_id(session_row["host_id"])
    if not host_row:
        raise HTTPException(status_code=404, detail="Host not found")

    queue_items = queue_repo.list_session_queue(session_row["id"])
    queue_models = [_map_queue_item_to_schema(i) for i in queue_items]

    current_song_model: Optional[QueuedSongResponse] = None
    if session_row.get("current_song"):
        # resolve single queued song with joins
        qs = queue_repo.get_queued_song(session_row["current_song"])
        if qs:
            single_items = queue_repo.list_session_queue(session_row["id"])
            # find the one
            for it in single_items:
                if it["id"] == qs["id"]:
                    current_song_model = _map_queue_item_to_schema(it)
                    break

    return CurrentSessionResponse(
        session=_map_session_to_schema(session_row, host_row),
        current_song=current_song_model,
        queue=queue_models,
    )


def create_session_for_user(auth: AuthenticatedClient, request: SessionCreateRequest) -> CurrentSessionResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)

    created = session_repo.create_session(host_id=user_id, join_code=request.join_code)
    # Set creator's current_session to the new session
    user_repo.set_current_session(user_id=user_id, session_id=created["id"])

    host_row = user_repo.get_by_id(created["host_id"])
    if not host_row:
        raise HTTPException(status_code=404, detail="Host not found")

    return CurrentSessionResponse(
        session=_map_session_to_schema(created, host_row),
        current_song=None,
        queue=[],
    )


def join_session_by_code(auth: AuthenticatedClient, request: SessionJoinRequest) -> CurrentSessionResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)
    queue_repo = QueueRepository(client)

    session_row = session_repo.get_by_join_code(request.join_code)
    if not session_row:
        raise HTTPException(status_code=404, detail="Session not found")

    # Set user's current_session
    user_repo.set_current_session(user_id=user_id, session_id=session_row["id"])

    host_row = user_repo.get_by_id(session_row["host_id"])
    if not host_row:
        raise HTTPException(status_code=404, detail="Host not found")

    queue_items = queue_repo.list_session_queue(session_row["id"])
    queue_models = [_map_queue_item_to_schema(i) for i in queue_items]

    return CurrentSessionResponse(
        session=_map_session_to_schema(session_row, host_row),
        current_song=None,
        queue=queue_models,
    )


def leave_current_session_for_user(auth: AuthenticatedClient) -> Dict[str, Any]:
    client = auth.client
    user_id = auth.payload["sub"]
    user_repo = UserRepository(client)
    user_repo.set_current_session(user_id=user_id, session_id=None)
    return {"ok": True}


def control_session_for_user(auth: AuthenticatedClient, request: SessionControlRequest) -> Dict[str, Any]:
    """
    Host control implementation:
    - skip_current_track: marks current song as skipped and advances to next song
    """
    client = auth.client
    user_id = auth.payload["sub"]
    session_repo = SessionRepository(client)
    queue_repo = QueueRepository(client)

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        raise HTTPException(status_code=404, detail="No active session")

    session_details = session_repo.get_by_id(session_row["id"])
    if not session_details:
        raise HTTPException(status_code=404, detail="Session not found")
    if session_details["host_id"] != user_id:
        raise HTTPException(status_code=403, detail="You are not the host of this session")

    if request.skip_current_track:
        # Mark current song as skipped
        if session_details.get("current_song"):
            queue_repo.update_song_status(session_details["current_song"], "skipped")
        
        # Advance to next song
        _advance_to_next_song(session_repo, queue_repo, session_row["id"])

    return {"ok": True}


def _advance_to_next_song(
    session_repo: SessionRepository,
    queue_repo: QueueRepository,
    session_id: str
) -> None:
    """
    Helper function to move to the next song in the queue.
    Sets the next queued song as 'playing' and updates session.current_song.
    """
    # Get the next song in queue
    next_song = queue_repo.get_next_queued_song(session_id)
    
    if next_song:
        # Update the song status to playing
        queue_repo.update_song_status(next_song["id"], "playing")
        # Set it as the current song in the session
        session_repo.set_current_song(session_id=session_id, queued_song_id=next_song["id"])
    else:
        # No more songs in queue, clear current_song
        session_repo.set_current_song(session_id=session_id, queued_song_id=None)


def song_finished_for_user(auth: AuthenticatedClient) -> Dict[str, Any]:
    """
    Called when the current song finishes playing naturally.
    Marks it as 'played' and advances to the next song.
    Only the host can call this.
    """
    client = auth.client
    user_id = auth.payload["sub"]
    session_repo = SessionRepository(client)
    queue_repo = QueueRepository(client)

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        raise HTTPException(status_code=404, detail="No active session")

    session_details = session_repo.get_by_id(session_row["id"])
    if not session_details:
        raise HTTPException(status_code=404, detail="Session not found")
    if session_details["host_id"] != user_id:
        raise HTTPException(status_code=403, detail="You are not the host of this session")

    # Mark current song as played
    if session_details.get("current_song"):
        queue_repo.update_song_status(session_details["current_song"], "played")
    
    # Advance to next song
    _advance_to_next_song(session_repo, queue_repo, session_row["id"])

    return {"ok": True}


