from __future__ import annotations

from typing import Dict, Any
from fastapi import HTTPException

from app.core.auth import AuthenticatedClient
from app.repositories import SessionRepository, UserRepository, QueueRepository, SongRepository
from app.schemas.session import QueuedSongResponse, VoteRequest
from app.schemas.track import AddSongRequest, TrackOut
from app.schemas.user import User


def _map_queue_item(item: Dict[str, Any]) -> QueuedSongResponse:
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


def add_song_to_queue_for_user(auth: AuthenticatedClient, request: AddSongRequest) -> QueuedSongResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)
    song_repo = SongRepository(client)
    queue_repo = QueueRepository(client)

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        raise HTTPException(status_code=400, detail="User has no active session")

    # Ensure song exists (upsert)
    song_repo.upsert_song(
        external_id=request.id,
        name=request.name,
        artist=request.artists,
        album=request.album,
        durationMSs=request.duration_ms,
        image_url=str(request.image_url),
        isrc_identifier=request.isrc,
        source=request.source,
    )

    queued = queue_repo.add_song_to_queue(
        session_id=session_row["id"],
        added_by_id=user_id,
        song_external_id=request.id,
    )

    # Auto-play if no song is currently playing
    if not session_row.get("current_song"):
        session_repo.set_current_song(
            session_id=session_row["id"],
            queued_song_id=queued["id"]
        )

    # Build enriched response using list_session_queue to reuse joins
    queue_items = queue_repo.list_session_queue(session_row["id"])
    for item in queue_items:
        if item["id"] == queued["id"]:
            return _map_queue_item(item)

    # Fallback if not found in list (shouldn't happen)
    raise HTTPException(status_code=500, detail="Failed to build queued song response")


def vote_for_queued_song(auth: AuthenticatedClient, queued_song_id: str, request: VoteRequest) -> Dict[str, Any]:
    client = auth.client
    user_id = auth.payload["sub"]

    queue_repo = QueueRepository(client)
    result = queue_repo.vote_on_song(queued_song_id=queued_song_id, user_id=user_id, vote_value=int(request.vote_value))
    return {"ok": True, "total_votes": int(result["total_votes"])}


