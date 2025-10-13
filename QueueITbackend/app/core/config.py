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

    client_id: str | None = os.getenv("CLIENT_ID")
    client_secret: str | None = os.getenv("CLIENT_SECRET")

    allowed_origins: List[str] = Field(
        default_factory=lambda: [o for o in os.getenv("ALLOWED_ORIGINS", "*").split(",") if o]
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


