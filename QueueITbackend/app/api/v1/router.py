from fastapi import APIRouter

from app.api.v1.spotify import router as spotify_router
from app.api.v1.sessions import router as sessions_router
from app.api.v1.songs import router as songs_router


api_router = APIRouter()


@api_router.get("/ping")
def ping() -> dict:
    return {"ok": True}


api_router.include_router(spotify_router, prefix="/spotify", tags=["spotify"])
api_router.include_router(sessions_router, prefix="/sessions", tags=["sessions"])
api_router.include_router(songs_router, prefix="/songs", tags=["songs"])


