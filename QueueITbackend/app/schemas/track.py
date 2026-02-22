from typing import List, Optional, Annotated, Literal

from pydantic import BaseModel, Field, HttpUrl


class TrackOut(BaseModel):
    id: Annotated[str, Field(..., alias="external_id", serialization_alias="id", description="Track ID (Spotify or Apple Music)")]
    isrc: Annotated[str, Field(..., alias="isrc_identifier", serialization_alias="isrc", description="International Standard Recording Code")]
    name: str = Field(..., description="Track title")
    artists: Annotated[str, Field(..., alias="artist", serialization_alias="artists", description="Primary artists names in a & separated list")]
    album: str = Field(..., description="Album name")
    duration_ms: Annotated[int, Field(..., alias="durationMSs", serialization_alias="duration_ms", ge=0, description="Duration in milliseconds")]
    image_url: Optional[HttpUrl] = Field(None, description="Album art URL (largest available)")
    source: Annotated[str, Field(default="spotify", description="Music service source (spotify or apple_music)")]

    class Config:
        from_attributes = True
        populate_by_name = True
        
        json_schema_extra = {
            "example": {
                "id": "3n3Ppam7vgaVa1iaRUc9Lp",
                "isrc": "US-QW-000000000000",
                "name": "Mr. Brightside",
                "artists": "The Killers",
                "album": "Hot Fuss",
                "duration_ms": 222075,
                "image_url": "https://i.scdn.co/image/ab67616d0000b273...",
                "source": "spotify"
            }
        }

class AddSongRequest(BaseModel):
    id: str = Field(..., description="Track ID (Spotify or Apple Music catalog ID)")
    isrc: str = Field(..., description="International Standard Recording Code")
    name: str = Field(..., description="Track title")
    artists: str = Field(..., description="Primary artists names in a & separated list")
    album: str = Field(..., description="Album name")
    duration_ms: int = Field(..., ge=0, description="Duration in milliseconds")
    image_url: HttpUrl = Field(..., description="Album art URL (largest available)")
    source: Literal["spotify", "apple_music"] = Field(default="spotify", description="Music service source")

    class Config:
        populate_by_name = True
        json_schema_extra = {
            "example": {
                "id": "3n3Ppam7vgaVa1iaRUc9Lp",
                "isrc": "US-QW-000000000000",
                "name": "Mr. Brightside",
                "artists": "The Killers",
                "album": "Hot Fuss",
                "duration_ms": 222075,
                "image_url": "https://i.scdn.co/image/ab67616d0000b273...",
                "source": "spotify"
            }
        }