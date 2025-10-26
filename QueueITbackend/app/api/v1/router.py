from fastapi import APIRouter, Depends

from app.api.v1.spotify import router as spotify_router
from app.api.v1.sessions import router as sessions_router
from app.api.v1.songs import router as songs_router

from app.core.auth import verify_jwt

# This dependency will be applied to EVERY route in this router
api_router = APIRouter(
    dependencies=[Depends(verify_jwt)]
)

@api_router.get("/ping")
def ping() -> dict:
    return {"ok": True}

@api_router.get("/secure-test")
def get_secure_test(auth_data: dict = Depends(verify_jwt)):
    """A test endpoint to see the verified token payload."""
    return {"message": "Your token is valid!", "user_id": auth_data["payload"].get("sub")}


api_router.include_router(spotify_router, prefix="/spotify", tags=["spotify"])
api_router.include_router(sessions_router, prefix="/sessions", tags=["sessions"])
api_router.include_router(songs_router, prefix="/songs", tags=["songs"])


