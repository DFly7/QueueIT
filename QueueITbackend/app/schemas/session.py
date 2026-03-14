# app/schemas/session.py
from pydantic import BaseModel, Field, ConfigDict, field_serializer
from typing import Dict, Optional, List, Literal
import uuid
import datetime

# Import the other schemas we'll nest
from app.schemas.user import User
from app.schemas.track import TrackOut

# --- Vote Schemas ---

class VoteRequest(BaseModel):
    """
    Schema for POST /songs/{queued_song_id}/vote
    """
    vote_value: Literal[1, -1]


# --- Queued Song Schemas ---

class QueuedSongResponse(BaseModel):
    """
    Represents a single song in the queue.
    This is a "View Model", not a direct table map.
    """
    id: uuid.UUID  # The ID of the queued_songs row
    status: str    # The user-defined status (e.g., "queued", "playing")
    added_at: datetime.datetime

    votes: int  
    song: TrackOut 
    added_by: User

    # Tier sorting metadata — set by the DB trigger on the votes table
    last_entered_tier_at: Optional[datetime.datetime] = None
    entered_tier_by_gain: bool = True  # True = rose into tier; False = fell into tier

    @field_serializer('added_at')
    def serialize_datetime(self, dt: datetime.datetime, _info):
        """Ensure datetime always has timezone info for iOS compatibility"""
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt.isoformat()

    @field_serializer('last_entered_tier_at')
    def serialize_tier_datetime(self, dt: Optional[datetime.datetime], _info):
        if dt is None:
            return None
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt.isoformat()

    model_config = ConfigDict(from_attributes=True)

# --- Session Schemas ---

class SessionCreateRequest(BaseModel):
    """
    Body for POST /sessions/create
    The user provides their own join code.
    """
    # We add validation to ensure the code is reasonable
    join_code: str = Field(
        ..., 
        min_length=4, 
        max_length=20, 
        description="A user-defined code to join the session"
    )

    
class SessionJoinRequest(BaseModel):
    """
    Schema for POST /sessions/join
    """
    join_code: str = Field(..., min_length=4, max_length=20) # Example validation


class SessionControlRequest(BaseModel):
    """
    Schema for PATCH /sessions/control_session
    Note: These fields are for your API logic, not DB columns.
    """
    is_locked: Optional[bool] = None
    skip_current_track: Optional[bool] = None
    pause_playback: Optional[bool] = None


class SessionBase(BaseModel):
    """
    The base response for a session.
    """
    id: uuid.UUID
    join_code: str
    created_at: datetime.datetime
    host: User  # Nested host data
    host_provider: Optional[Literal["apple", "spotify"]] = "spotify"  # Host's music provider for the session

    @field_serializer('created_at')
    def serialize_datetime(self, dt: datetime.datetime, _info):
        """Ensure datetime always has timezone info for iOS compatibility"""
        if dt.tzinfo is None:
            # If naive, assume UTC
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt.isoformat()

    model_config = ConfigDict(from_attributes=True)

class CurrentSessionResponse(BaseModel):
    """
    The main response for GET /sessions/current
    This is the "all-in-one" object for the client.
    """
    session: SessionBase
    current_song: Optional[QueuedSongResponse] = None
    queue: List[QueuedSongResponse]
    # Map of queued_song_id (str) → vote_value (1 or -1) for the requesting user.
    # Always a dict — never None — so the iOS client can safely iterate without
    # Optional unwrapping. Empty dict means the user has no votes in this session.
    my_votes: Dict[str, int] = {}
    # Crowdsourced skip fields
    skip_request_count: int = 0
    participant_count: int = 1
    user_requested_skip: bool = False


class SkipRequestResponse(BaseModel):
    """Response for POST /sessions/request_skip"""
    ok: bool
    skip_request_count: int
    participant_count: int
    skipped: bool