from fastapi import APIRouter, HTTPException, Query

from app.services.spotify_service import search_spotify


router = APIRouter()


@router.get("/search")
def search(
    q: str = Query(..., description="Search query"),
    type: str = Query("track", pattern="^(track|artist|album|playlist)$"),
    limit: int = Query(5, ge=1, le=50),
):
    try:
        return search_spotify(query=q, search_type=type, limit=limit)
    except ValueError as exc:  # missing credentials or invalid inputs
        raise HTTPException(status_code=400, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:  # unexpected
        raise HTTPException(status_code=500, detail=str(exc))


