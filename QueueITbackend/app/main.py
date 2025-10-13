from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings


settings = get_settings()

app = FastAPI(title=settings.app_name)

cors_origins = ["*"] if settings.allowed_origins == ["*"] else settings.allowed_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


app.include_router(api_router, prefix="/api/v1")


@app.on_event("startup")
def on_startup() -> None:
    # Print relative docs paths; runner prints absolute URL
    print("FastAPI app started. Docs: /docs | Redoc: /redoc | Health: /healthz")

