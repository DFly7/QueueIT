# Session Management 🚪
# These endpoints handle creating, joining, and managing the core listening sessions.
# POST /sessions/create
# Description: Creates a new music session. This endpoint will generate a unique join_code, set the current user as the host_id, and return the new session details. This is the starting point for any party.
# POST /sessions/join
# Description: Allows a user to join an existing session using a join_code. The request body will contain the code. On the backend, this updates the users table, setting the user's current_session_id to the ID of the session they are joining.
# GET /sessions/current
# Description: Fetches all the data needed to render the main screen for the user's active session. This is the most important GET request. The response should include session details (like join_code, is_locked), the "Now Playing" track, and the list of all queued songs, correctly sorted by votes and creation time.
# POST /sessions/leave
# Description: Removes a user from their current session. This simply sets their current_session_id back to NULL.
# PATCH /sessions/control_session
# Description: Used by the session host for administrative actions. The request body could specify actions like lock_queue: true, skip_current_track: true, or pause_playback: true. This endpoint centralizes all host controls.

from fastapi import APIRouter

router = APIRouter()


@router.post("/create")
def create_session() -> dict:
    return {"ok": True}

@router.post("/join")
def join_session() -> dict:
    return {"ok": True}

@router.get("/current")
def get_current_session() -> dict:
    return {"ok": True}

@router.post("/leave")
def leave_session() -> dict:
    return {"ok": True}

@router.patch("/control_session")
def control_session() -> dict:
    return {"ok": True}