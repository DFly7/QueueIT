import os
from functools import lru_cache
from typing import List

from dotenv import load_dotenv
from pydantic import BaseModel, Field


load_dotenv()


class Settings(BaseModel):
    app_name: str = "QueueIT API"
    environment: str = os.getenv("ENVIRONMENT", "development")
    debug: bool = environment != "production"

    # Logging configuration
    log_level: str = os.getenv("LOG_LEVEL", "INFO" if environment == "production" else "DEBUG")
    log_json: bool = os.getenv("LOG_JSON", "true" if environment == "production" else "false").lower() == "true"
    
    # Access log enrichment
    log_request_body: bool = os.getenv("LOG_REQUEST_BODY", "true").lower() == "true"
    log_request_body_max_size: int = int(os.getenv("LOG_REQUEST_BODY_MAX_SIZE", "1000"))  # bytes
    
    # Sentry configuration (optional)
    sentry_dsn: str | None = os.getenv("SENTRY_DSN")
    sentry_environment: str = os.getenv("SENTRY_ENVIRONMENT", environment)
    sentry_traces_sample_rate: float = float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.1"))
    
    # Prometheus metrics
    enable_metrics: bool = os.getenv("ENABLE_METRICS", "true").lower() == "true"

    # Rate limiting
    rate_limit_enabled: bool = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"
    rate_limit_default: str = os.getenv("RATE_LIMIT_DEFAULT", "100/minute")

    spotify_client_id: str | None = os.getenv("SPOTIFY_CLIENT_ID")
    spotify_client_secret: str | None = os.getenv("SPOTIFY_CLIENT_SECRET")

    # Apple Music API configuration
    apple_team_id: str | None = os.getenv("APPLE_TEAM_ID")
    apple_key_id: str | None = os.getenv("APPLE_KEY_ID")
    # Production (Railway): base64-encoded .p8 key stored as env var
    # Local dev: path to .p8 file (falls back to this if base64 not set)
    apple_private_key_base64: str | None = os.getenv("APPLE_PRIVATE_KEY_BASE64")
    apple_private_key_path: str | None = os.getenv("APPLE_PRIVATE_KEY_PATH")
    apple_media_id: str | None = os.getenv("APPLE_MEDIA_ID")

    supabase_url: str | None = os.getenv("SUPABASE_URL")
    supabase_public_anon_key: str | None = os.getenv("SUPABASE_PUBLIC_ANON_KEY")

    allowed_origins: List[str] = Field(
        default_factory=lambda: [o for o in os.getenv("ALLOWED_ORIGINS", "*").split(",") if o]
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


