from fastapi import APIRouter

from app.api.v1.spotify import router as spotify_router


api_router = APIRouter()


@api_router.get("/ping")
def ping() -> dict:
    return {"ok": True}


api_router.include_router(spotify_router, prefix="/spotify", tags=["spotify"])


