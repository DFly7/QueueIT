# Song & Queue Management 🎶
# These endpoints are for interacting with the music queue itself.
# POST /songs/add
# Description: Adds a new song to the current session's queue. The request body must include the song's details (e.g., song_identifier, title, artist from the search results). This creates a new record in the queued_songs table linked to the user's session.
# Voting System 👍👎
# This single, crucial endpoint handles all voting actions.
# POST /songs/{queued_song_id}/vote
# Description: Allows the authenticated user to cast or change their vote for a specific song in the queue. The request body would contain the vote value (e.g., { "value": 1 } for an upvote or { "value": -1 } for a downvote). This endpoint will INSERT a new row into the votes table or UPDATE an existing one if the user changes their vote.


# app/api/v1/songs.py
from fastapi import APIRouter, Depends, HTTPException
from supabase import Client
from app.core.auth import get_supabase_client_as_user
# Import your schemas, e.g., from app.schemas.track import Track

router = APIRouter()

@router.get("/my-songs")
def get_my_songs(
    # This dependency gives you the RLS-enabled client
    supabase: Client = Depends(get_supabase_client_as_user)
):
    """
    Fetches songs for the currently authenticated user.
    RLS policies are automatically enforced by Supabase.
    """
    try:
        # RLS is enforced here! This will only return songs
        # that the user's RLS policy allows them to see.
        response = supabase.from_("songs").select("*").execute()
        
        return response.data
        
    except Exception as e:
        # This could catch RLS violations or other DB errors
        raise HTTPException(status_code=400, detail=str(e))



@router.post("/add")
def add_song() -> dict:
    return {"ok": True}

@router.post("/{queued_song_id}/vote")
def vote_for_song() -> dict:
    return {"ok": True}