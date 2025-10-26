from typing import List, Optional

from pydantic import BaseModel, Field, HttpUrl


class TrackOut(BaseModel):
    id: str = Field(..., description="Spotify track ID")
    isrc: str = Field(..., description="International Standard Recording Code")
    name: str = Field(..., description="Track title")
    artists: str = Field(..., description="Primary artists names in a & separated list")
    album: str = Field(..., description="Album name")
    duration_ms: int = Field(..., ge=0, description="Duration in milliseconds")
    image_url: Optional[HttpUrl] = Field(None, description="Album art URL (largest available)")

    class Config:
        json_schema_extra = {
            "example": {
                "id": "3n3Ppam7vgaVa1iaRUc9Lp",
                "isrc": "US-QW-000000000000",
                "name": "Mr. Brightside",
                "artists": "The Killers & The Rolling Stones",
                "album": "Hot Fuss",
                "duration_ms": 222075,
                "image_url": "https://i.scdn.co/image/ab67616d0000b273..."
            }
        }


