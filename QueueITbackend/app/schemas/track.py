from typing import List, Optional

from pydantic import BaseModel, Field, HttpUrl


class TrackOut(BaseModel):
    id: str = Field(..., description="Spotify track ID")
    name: str = Field(..., description="Track title")
    artists: List[str] = Field(..., description="Primary artist names")
    album: str = Field(..., description="Album name")
    duration_ms: int = Field(..., ge=0, description="Duration in milliseconds")
    image_url: Optional[HttpUrl] = Field(None, description="Album art URL (largest available)")
    preview_url: Optional[HttpUrl] = Field(None, description="30s preview MP3 URL if available")
    external_url: Optional[HttpUrl] = Field(None, description="Spotify web URL for the track")

    class Config:
        json_schema_extra = {
            "example": {
                "id": "3n3Ppam7vgaVa1iaRUc9Lp",
                "name": "Mr. Brightside",
                "artists": ["The Killers"],
                "album": "Hot Fuss",
                "duration_ms": 222075,
                "image_url": "https://i.scdn.co/image/ab67616d0000b273...",
                "preview_url": "https://p.scdn.co/mp3-preview/...",
                "external_url": "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp",
            }
        }


