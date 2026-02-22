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

from fastapi import APIRouter, Depends, Body, HTTPException
from app.core.auth import AuthenticatedClient, get_authenticated_client
from app.schemas.session import (
    SessionJoinRequest,
    CurrentSessionResponse,
    SessionCreateRequest,
    SessionControlRequest,
)
from app.services.session_service import (
    create_session_for_user,
    join_session_by_code,
    get_current_session_for_user,
    leave_current_session_for_user,
    control_session_for_user,
)
router = APIRouter()


@router.post("/create", response_model=CurrentSessionResponse)
def create_session(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
    session_request: SessionCreateRequest = Body(...),
):
    return create_session_for_user(auth, session_request)


    # return CurrentSessionResponse(
    #     session=SessionBase(
    #         id=session.data[0]["id"],
    #         join_code=session.data[0]["join_code"],
    #         created_at=session.data[0]["created_at"],
    #         host=User(
    #             id=session.data[0]["host_id"],
    #             username=supabase.auth.get_user().data.user.email
    #         )
    #     ),
    #     current_song=None,
    #     queue=[]
    # )

@router.post("/join", response_model=CurrentSessionResponse)
def join_session(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
    join_request: SessionJoinRequest = Body(...),
):
    return join_session_by_code(auth, join_request)

@router.get("/current", response_model=CurrentSessionResponse)
def get_current_session(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
):
    return get_current_session_for_user(auth)

@router.post("/leave")
def leave_session(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
):
    return leave_current_session_for_user(auth)

@router.patch("/control_session")
def control_session(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
    request: SessionControlRequest = Body(...),
):
    return control_session_for_user(auth, request)

@router.post("/song_finished")
def mark_song_finished(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
):
    """
    Called by the host when the current song finishes playing naturally.
    Marks it as 'played' and advances to the next song.
    """
    from app.services.session_service import song_finished_for_user
    return song_finished_for_user(auth)