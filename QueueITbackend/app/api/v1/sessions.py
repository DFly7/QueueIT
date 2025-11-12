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

from fastapi import APIRouter, Depends
from supabase import Client
from app.core.auth import get_supabase_client_as_user
from app.schemas.session import SessionJoinRequest, SessionBase, CurrentSessionResponse, SessionCreateRequest
from fastapi import Body
from app.core.auth import AuthenticatedClient, get_authenticated_client
router = APIRouter()


@router.post("/create")
def create_session(    
    auth: AuthenticatedClient = Depends(get_authenticated_client),
    session_request: SessionCreateRequest = Body(...)
    ) -> dict:

    current_user_id = auth.payload["sub"]
    supabase_client = auth.client
    
    print(f"User {current_user_id} is creating a session")

    # response = supabase_client.from_("sessions").select("*").execute()
    # print(f"Response: {response}")

    try:
        response = supabase_client.from_("sessions").insert({
            "join_code": session_request.join_code,
            "host_id": current_user_id
        }).execute()
    except Exception as e:
        print(f"Error: {e}")
        return {"error": str(e)}


    return {"ok": True}


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

@router.post("/join")
def join_session(
    supabase: Client = Depends(get_supabase_client_as_user),
    join_request: SessionJoinRequest = Body(...)
    ) -> dict:
    return {"ok": True}

@router.get("/current")
def get_current_session(
    supabase: Client = Depends(get_supabase_client_as_user)
    ) -> dict:
    return {"ok": True}

@router.post("/leave")
def leave_session(
    supabase: Client = Depends(get_supabase_client_as_user)
    ) -> dict:
    return {"ok": True}

@router.patch("/control_session")
def control_session(
    supabase: Client = Depends(get_supabase_client_as_user)
    ) -> dict:
    return {"ok": True}