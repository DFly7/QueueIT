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
    service_name: str = os.getenv("SERVICE_NAME", "queueit-backend")
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
    log_json: bool = os.getenv("LOG_JSON", "true").lower() == "true"
    request_id_header: str = os.getenv("REQUEST_ID_HEADER", "X-Request-ID")
    log_slow_query_ms: float = float(os.getenv("LOG_SLOW_QUERY_MS", "250"))
    enable_metrics: bool = os.getenv("ENABLE_PROMETHEUS", "true").lower() == "true"
    log_enrichment_enabled: bool = os.getenv("LOG_ENRICHMENT", "true").lower() == "true"
    sentry_dsn: str | None = os.getenv("SENTRY_DSN")


    spotify_client_id: str | None = os.getenv("SPOTIFY_CLIENT_ID")
    spotify_client_secret: str | None = os.getenv("SPOTIFY_CLIENT_SECRET")

    supabase_url: str | None = os.getenv("SUPABASE_URL")
    supabase_public_anon_key: str | None = os.getenv("SUPABASE_PUBLIC_ANON_KEY")

    allowed_origins: List[str] = Field(
        default_factory=lambda: [o for o in os.getenv("ALLOWED_ORIGINS", "*").split(",") if o]
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


