from __future__ import annotations

from typing import Optional, Dict, Any, List
from fastapi import HTTPException
import structlog

from app.core.auth import AuthenticatedClient
from app.repositories import SessionRepository, UserRepository, QueueRepository, SongRepository, SkipRequestRepository
from app.schemas.session import (
    SessionCreateRequest,
    SessionJoinRequest,
    SessionControlRequest,
    SessionBase,
    CurrentSessionResponse,
    QueuedSongResponse,
    SkipRequestResponse,
)
from app.schemas.user import User
from app.schemas.track import TrackOut

logger = structlog.get_logger(__name__)


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
        source="apple_music" if item["song"].get("source") == "apple" else (item["song"].get("source") or "spotify"),
    )
    added_by = User(
        id=item["added_by"]["id"],
        username=item["added_by"].get("username"),
        is_anonymous=item["added_by"].get("is_anonymous", False),
    )
    return QueuedSongResponse(
        id=item["id"],
        status=item["status"],
        added_at=item["added_at"],
        votes=int(item["votes"]),
        song=track,
        added_by=added_by,
        last_entered_tier_at=item.get("last_entered_tier_at"),
        entered_tier_by_gain=item.get("entered_tier_by_gain", True),
    )


def _map_session_to_schema(session_row: Dict[str, Any], host_row: Dict[str, Any]) -> SessionBase:
    return SessionBase(
        id=session_row["id"],
        join_code=session_row["join_code"],
        created_at=session_row["created_at"],
        host=User(
            id=host_row["id"],
            username=host_row.get("username"),
            is_anonymous=host_row.get("is_anonymous", False),
        ),
    )


def get_current_session_for_user(auth: AuthenticatedClient) -> CurrentSessionResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)
    queue_repo = QueueRepository(client)
    skip_repo = SkipRequestRepository(client)

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

    my_votes = queue_repo.get_user_votes_for_session(
        session_id=session_row["id"], user_id=user_id
    )

    skip_request_count = skip_repo.get_skip_request_count(session_row["id"])
    participant_count = skip_repo.get_participant_count(session_row["id"])
    user_requested_skip = skip_repo.user_has_requested_skip(
        session_id=session_row["id"], user_id=user_id
    )

    return CurrentSessionResponse(
        session=_map_session_to_schema(session_row, host_row),
        current_song=current_song_model,
        queue=queue_models,
        my_votes=my_votes,
        skip_request_count=skip_request_count,
        participant_count=participant_count,
        user_requested_skip=user_requested_skip,
    )


def create_session_for_user(auth: AuthenticatedClient, request: SessionCreateRequest) -> CurrentSessionResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)

    # Get host user data to check music_provider and anonymous status
    host_user = user_repo.get_by_id(user_id)
    if not host_user:
        raise HTTPException(status_code=404, detail="User not found")

    # Anonymous (App Clip) users cannot host sessions
    if host_user.get("is_anonymous", False):
        raise HTTPException(
            status_code=403,
            detail="Guest users cannot create sessions. Install the full app to host."
        )

    # Validate host has a music provider (not 'none')
    music_provider = host_user.get("music_provider", "none")
    if music_provider == "none":
        raise HTTPException(
            status_code=400,
            detail="You need to connect a music provider (Apple Music or Spotify) to host sessions"
        )
    
    # Create session with host_provider from user's music_provider
    created = session_repo.create_session(
        host_id=user_id,
        join_code=request.join_code,
        host_provider=music_provider
    )
    
    # Set creator's current_session to the new session
    user_repo.set_current_session(user_id=user_id, session_id=created["id"])

    host_row = user_repo.get_by_id(created["host_id"])
    if not host_row:
        raise HTTPException(status_code=404, detail="Host not found")

    skip_repo = SkipRequestRepository(client)
    participant_count = skip_repo.get_participant_count(created["id"])

    return CurrentSessionResponse(
        session=_map_session_to_schema(created, host_row),
        current_song=None,
        queue=[],
        my_votes={},
        skip_request_count=0,
        participant_count=participant_count,
        user_requested_skip=False,
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

    current_song_model: Optional[QueuedSongResponse] = None
    if session_row.get("current_song"):
        # resolve single queued song with joins
        qs = queue_repo.get_queued_song(session_row["current_song"])
        if qs:
            # find the current song in queue_items
            for it in queue_items:
                if it["id"] == qs["id"]:
                    current_song_model = _map_queue_item_to_schema(it)
                    break

    my_votes = queue_repo.get_user_votes_for_session(
        session_id=session_row["id"], user_id=user_id
    )

    skip_repo = SkipRequestRepository(client)
    skip_request_count = skip_repo.get_skip_request_count(session_row["id"])
    participant_count = skip_repo.get_participant_count(session_row["id"])
    user_requested_skip = skip_repo.user_has_requested_skip(
        session_id=session_row["id"], user_id=user_id
    )

    return CurrentSessionResponse(
        session=_map_session_to_schema(session_row, host_row),
        current_song=current_song_model,
        queue=queue_models,
        my_votes=my_votes,
        skip_request_count=skip_request_count,
        participant_count=participant_count,
        user_requested_skip=user_requested_skip,
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
    skip_repo = SkipRequestRepository(client)

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
        
        # Advance to next song (also clears skip requests)
        _advance_to_next_song(session_repo, queue_repo, session_row["id"], skip_repo)

    return {"ok": True}


def _advance_to_next_song(
    session_repo: SessionRepository,
    queue_repo: QueueRepository,
    session_id: str,
    skip_repo: Optional["SkipRequestRepository"] = None,
) -> Optional[Dict[str, Any]]:
    """
    Helper function to move to the next song in the queue.
    Sets the next queued song as 'playing' and updates session.current_song.
    Also clears any outstanding skip requests for this session.
    Returns the next song dict if found, None otherwise.
    """
    # Clear skip requests whenever we advance to the next song
    if skip_repo is not None:
        skip_repo.clear_skip_requests(session_id)

    # Get the next song in queue
    next_song = queue_repo.get_next_queued_song(session_id)
    
    if next_song:
        logger.info(
            "advancing_to_next_song",
            session_id=session_id,
            next_song_id=next_song["id"],
            next_song_name=next_song.get("song", {}).get("name", "unknown")
        )
        # Update the song status to playing
        queue_repo.update_song_status(next_song["id"], "playing")
        # Set it as the current song in the session
        session_repo.set_current_song(session_id=session_id, queued_song_id=next_song["id"])
        return next_song
    else:
        logger.info("no_more_songs_in_queue", session_id=session_id)
        # No more songs in queue, clear current_song
        session_repo.set_current_song(session_id=session_id, queued_song_id=None)
        return None


def request_skip_for_user(auth: AuthenticatedClient) -> SkipRequestResponse:
    """
    Any session participant can request to skip the current song.
    When more than 50% of participants have requested a skip the song is
    automatically advanced (same flow as host skip) and requests are cleared.
    """
    client = auth.client
    user_id = auth.payload["sub"]
    session_repo = SessionRepository(client)
    queue_repo = QueueRepository(client)
    skip_repo = SkipRequestRepository(client)

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        raise HTTPException(status_code=404, detail="No active session")

    session_id = session_row["id"]

    # Upsert the skip request (idempotent – repeated taps are safe)
    skip_repo.insert_request(session_id=session_id, user_id=user_id)

    skip_request_count = skip_repo.get_skip_request_count(session_id)
    participant_count = skip_repo.get_participant_count(session_id)

    skipped = False
    if skip_request_count > participant_count / 2:
        logger.info(
            "crowdsourced_skip_threshold_reached",
            session_id=session_id,
            skip_request_count=skip_request_count,
            participant_count=participant_count,
        )
        # Use a single SECURITY DEFINER RPC for the full advance — regular
        # participants cannot UPDATE queued_songs or sessions via RLS directly.
        # The RPC handles: mark current as skipped, clear skip_requests,
        # find next song, mark it playing, update sessions.current_song.
        skip_repo.crowdsourced_skip_advance(session_id)
        skip_request_count = 0
        skipped = True

    return SkipRequestResponse(
        ok=True,
        skip_request_count=skip_request_count,
        participant_count=participant_count,
        skipped=skipped,
    )


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
    skip_repo = SkipRequestRepository(client)

    logger.info("song_finished_called", user_id=user_id)

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        logger.warning("song_finished_no_session", user_id=user_id)
        raise HTTPException(status_code=404, detail="No active session")

    session_details = session_repo.get_by_id(session_row["id"])
    if not session_details:
        logger.warning("song_finished_session_not_found", session_id=session_row["id"])
        raise HTTPException(status_code=404, detail="Session not found")
    if session_details["host_id"] != user_id:
        logger.warning("song_finished_not_host", user_id=user_id, host_id=session_details["host_id"])
        raise HTTPException(status_code=403, detail="You are not the host of this session")

    current_song_id = session_details.get("current_song")
    logger.info(
        "song_finished_processing",
        session_id=session_row["id"],
        current_song_id=current_song_id
    )

    # Mark current song as played
    if current_song_id:
        queue_repo.update_song_status(current_song_id, "played")
        logger.info("song_marked_as_played", queued_song_id=current_song_id)
    
    # Advance to next song (also clears skip requests)
    next_song = _advance_to_next_song(session_repo, queue_repo, session_row["id"], skip_repo)

    logger.info(
        "song_finished_complete",
        session_id=session_row["id"],
        next_song_id=next_song["id"] if next_song else None,
        next_song_name=next_song.get("song", {}).get("name") if next_song else None
    )

    return {"ok": True}


