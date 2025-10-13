from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query

# We'll need a wrapper schema for the search results list
from app.schemas.track import TrackOut
from app.services.spotify_service import search_spotify
from pydantic import BaseModel

router = APIRouter()

# --- Pydantic model to represent the structure of Spotify's search response ---
# This ensures our API always returns a consistent shape.
class SearchResults(BaseModel):
    tracks: List[TrackOut]

# Helper function to parse the complex Spotify response and fit it to our model
def parse_spotify_results(spotify_data: dict) -> SearchResults:
    items = spotify_data.get("tracks", {}).get("items", [])
    tracks = []
    for item in items:
        # Check if essential data is present
        if not item or not item.get("album"):
            continue

        tracks.append(
            TrackOut(
                id=item.get("id"),
                name=item.get("name"),
                artists=[artist["name"] for artist in item.get("artists", [])],
                album=item.get("album", {}).get("name"),
                duration_ms=item.get("duration_ms"),
                image_url=item.get("album", {}).get("images", [{}])[0].get("url"),
                preview_url=item.get("preview_url"),
                external_url=item.get("external_urls", {}).get("spotify"),
            )
        )
    return SearchResults(tracks=tracks)


@router.get("/search", response_model=SearchResults) # <-- ADDED: response_model
def search(
    q: str = Query(..., min_length=1, description="Search query for a track"),
    limit: int = Query(10, ge=1, le=50, description="Number of results to return"),
):
    """
    Search for tracks on Spotify.
    """
    try:
        # The service still returns raw data
        raw_results = search_spotify(query=q, search_type="track", limit=limit)
        # We parse the raw data into our clean Pydantic model before returning
        return parse_spotify_results(raw_results)

    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except requests.exceptions.HTTPError as exc:
        # Catch errors from Spotify's API (e.g., 401 Unauthorized, 404 Not Found)
        raise HTTPException(
            status_code=exc.response.status_code,
            detail=f"Error from Spotify API: {exc.response.text}",
        )
    except Exception as exc:
        # Catch any other unexpected errors
        raise HTTPException(status_code=500, detail=f"An internal error occurred: {exc}")