# Song & Queue Management 🎶
# These endpoints are for interacting with the music queue itself.
# POST /songs/add
# Description: Adds a new song to the current session's queue. The request body must include the song's details (e.g., song_identifier, title, artist from the search results). This creates a new record in the queued_songs table linked to the user's session.
# Voting System 👍👎
# This single, crucial endpoint handles all voting actions.
# POST /songs/{queued_song_id}/vote
# Description: Allows the authenticated user to cast or change their vote for a specific song in the queue. The request body would contain the vote value (e.g., { "value": 1 } for an upvote or { "value": -1 } for a downvote). This endpoint will INSERT a new row into the votes table or UPDATE an existing one if the user changes their vote.


# app/api/v1/songs.py
from fastapi import APIRouter, Depends, HTTPException, Body
from app.core.auth import AuthenticatedClient, get_authenticated_client
from app.schemas.track import AddSongRequest
from app.schemas.session import VoteRequest, QueuedSongResponse
from app.services.queue_service import add_song_to_queue_for_user, vote_for_queued_song

router = APIRouter()

@router.get("/my-songs")
def get_my_songs():
    """
    Placeholder; implement if needed to scope songs to user.
    """
    return {"ok": True}



@router.post("/add", response_model=QueuedSongResponse)
def add_song(
    auth: AuthenticatedClient = Depends(get_authenticated_client),
    request: AddSongRequest = Body(...),
):
    return add_song_to_queue_for_user(auth, request)

@router.post("/{queued_song_id}/vote")
def vote_for_song(
    queued_song_id: str,
    auth: AuthenticatedClient = Depends(get_authenticated_client),
    request: VoteRequest = Body(...),
):
    return vote_for_queued_song(auth, queued_song_id, request)