from __future__ import annotations

from typing import Dict, Any
from fastapi import HTTPException

from app.core.auth import AuthenticatedClient
from app.repositories import SessionRepository, UserRepository, QueueRepository, SongRepository
from app.schemas.session import QueuedSongResponse, VoteRequest
from app.schemas.track import AddSongRequest, TrackOut
from app.schemas.user import User
from app.services.song_matching_service import get_song_matching_service
from app.logging_config import get_logger

logger = get_logger(__name__)


def _map_queue_item(item: Dict[str, Any]) -> QueuedSongResponse:
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


async def add_song_to_queue_for_user(auth: AuthenticatedClient, request: AddSongRequest) -> QueuedSongResponse:
    client = auth.client
    user_id = auth.payload["sub"]

    session_repo = SessionRepository(client)
    user_repo = UserRepository(client)
    song_repo = SongRepository(client)
    queue_repo = QueueRepository(client)
    matching_service = get_song_matching_service()

    session_row = session_repo.get_current_for_user(user_id)
    if not session_row:
        raise HTTPException(status_code=400, detail="User has no active session")

    # Get host user data to determine storefront
    host_row = user_repo.get_by_id(session_row["host_id"])
    if not host_row:
        raise HTTPException(status_code=404, detail="Host not found")
    
    host_provider = session_row.get("host_provider", "spotify")
    host_storefront = host_row.get("storefront", "us")
    song_source = request.source  # 'spotify' or 'apple'
    
    logger.info("Add song request", extra={
        "user_id": user_id,
        "session_id": session_row["id"],
        "song_source": song_source,
        "host_provider": host_provider,
        "song_id": request.id
    })
    
    # Cross-catalog resolution logic
    resolved_song_id = request.id
    resolved_source = song_source
    
    # Only resolve if guest is using Spotify and host is using Apple Music
    if song_source == "spotify" and host_provider == "apple":
        logger.info("Cross-catalog resolution needed (Spotify → Apple Music)", extra={
            "spotify_id": request.id,
            "storefront": host_storefront
        })
        
        # Resolve Spotify track to Apple Music
        resolution_result = await matching_service.resolve_spotify_to_apple(
            spotify_id=request.id,
            storefront=host_storefront
        )
        
        if not resolution_result:
            # Song not available on Apple Music
            raise HTTPException(
                status_code=422,
                detail=f"This track isn't available on Apple Music. Try another version?"
            )
        
        apple_id, match_method = resolution_result
        logger.info("✅ Song resolved to Apple Music", extra={
            "spotify_id": request.id,
            "apple_id": apple_id,
            "method": match_method
        })
        
        # Fetch Apple Music track data to store in songs table
        apple_track_data = await matching_service.extract_apple_music_track_data(
            apple_id=apple_id,
            storefront=host_storefront
        )
        
        if not apple_track_data:
            raise HTTPException(
                status_code=500,
                detail="Failed to fetch Apple Music track data"
            )
        
        # Use Apple Music track data
        resolved_song_id = apple_track_data["external_id"]
        resolved_source = "apple_music"
        
        # Override request data with Apple Music data
        song_repo.upsert_song(
            external_id=apple_track_data["external_id"],
            name=apple_track_data["name"],
            artist=apple_track_data["artist"],
            album=apple_track_data["album"],
            durationMSs=apple_track_data["duration_ms"],
            image_url=apple_track_data["image_url"],
            isrc_identifier=apple_track_data["isrc"],
            source="apple_music",
        )
    else:
        # No resolution needed - same provider or Apple guest (not implemented yet)
        logger.info("No cross-catalog resolution needed", extra={
            "song_source": song_source,
            "host_provider": host_provider
        })
        
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

    # Add resolved song to queue
    queued = queue_repo.add_song_to_queue(
        session_id=session_row["id"],
        added_by_id=user_id,
        song_external_id=resolved_song_id,
    )

    # Auto-play if no song is currently playing
    # Use atomic conditional update to prevent race conditions with concurrent adds
    was_set = session_repo.set_current_song_if_empty(
        session_id=session_row["id"],
        queued_song_id=queued["id"]
    )
    if was_set:
        # Only update status to "playing" if we successfully set this as current song
        queue_repo.update_song_status(queued["id"], "playing")

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


def remove_vote_from_queued_song(auth: AuthenticatedClient, queued_song_id: str) -> Dict[str, Any]:
    client = auth.client
    user_id = auth.payload["sub"]

    queue_repo = QueueRepository(client)
    result = queue_repo.remove_vote(queued_song_id=queued_song_id, user_id=user_id)
    return {"ok": True, "total_votes": int(result["total_votes"])}


