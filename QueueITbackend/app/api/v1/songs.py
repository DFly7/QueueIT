# Song & Queue Management 🎶
# These endpoints are for interacting with the music queue itself.
# POST /songs/add
# Description: Adds a new song to the current session's queue. The request body must include the song's details (e.g., song_identifier, title, artist from the search results). This creates a new record in the queued_songs table linked to the user's session.
# Voting System 👍👎
# This single, crucial endpoint handles all voting actions.
# POST /songs/{queued_song_id}/vote
# Description: Allows the authenticated user to cast or change their vote for a specific song in the queue. The request body would contain the vote value (e.g., { "value": 1 } for an upvote or { "value": -1 } for a downvote). This endpoint will INSERT a new row into the votes table or UPDATE an existing one if the user changes their vote.

from fastapi import APIRouter

router = APIRouter()


@router.post("/add")
def add_song() -> dict:
    return {"ok": True}

@router.post("/{queued_song_id}/vote")
def vote_for_song() -> dict:
    return {"ok": True}

