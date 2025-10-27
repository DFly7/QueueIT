from typing import List, Optional

from pydantic import BaseModel, Field, HttpUrl


class TrackOut(BaseModel):
    id: str = Field(..., alias="spotify_id", description="Spotify track ID")
    isrc: str = Field(..., alias="isrc_identifier", description="International Standard Recording Code")
    name: str = Field(..., description="Track title")
    artists: str = Field(..., alias="artist", description="Primary artists names in a & separated list")
    album: str = Field(..., description="Album name")
    duration_ms: int = Field(..., alias="durationMSs", ge=0, description="Duration in milliseconds")
    image_url: Optional[HttpUrl] = Field(None, description="Album art URL (largest available)")

    class Config:
        from_attributes = True  # Enable reading from ORM/dict-like objects
        populate_by_name = True # Allow using EITHER 'id' OR 'spotify_id' for input
        
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


