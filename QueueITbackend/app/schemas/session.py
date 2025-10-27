# app/schemas/session.py
from pydantic import BaseModel, Field
from typing import Optional, List, Literal
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

    class Config:
        from_attributes = True

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
    join_code: str = Field(..., min_length=4, max_length=10) # Example validation


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

    class Config:
        from_attributes = True

class CurrentSessionResponse(BaseModel):
    """
    The main response for GET /sessions/current
    This is the "all-in-one" object for the client.
    """
    session: SessionBase
    current_song: Optional[QueuedSongResponse] = None
    queue: List[QueuedSongResponse]