# app/schemas/user.py
from pydantic import BaseModel, Field, field_validator
import uuid
from typing import Optional, Literal

class User(BaseModel):
    """
    Standard response schema for a user.
    Hides sensitive data and foreign keys.
    """
    id: uuid.UUID = Field(..., description="User ID")
    username: Optional[str] = Field(None, description="Username")
    music_provider: Optional[Literal["apple", "spotify", "none"]] = Field("none", description="Music streaming provider")
    storefront: Optional[str] = Field("us", description="Apple Music storefront/region")
    is_anonymous: bool = Field(False, description="True for App Clip guests who signed in anonymously")

    class Config:
        from_attributes = True
        populate_by_name = True

        json_schema_extra = {
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "username": "Neon Giraffe",
                "music_provider": "none",
                "storefront": "us",
                "is_anonymous": True
            }
        }


class UserProfileUpdate(BaseModel):
    """Request schema for updating user profile"""
    username: Optional[str] = Field(None, min_length=3, max_length=30, description="Username (3-30 characters)")
    music_provider: Optional[Literal["apple", "spotify", "none"]] = Field(None, description="Music provider selection")
    storefront: Optional[str] = Field(None, min_length=2, max_length=10, description="Apple Music storefront (e.g., us, gb, ca)")
    
    @field_validator("username")
    @classmethod
    def validate_username(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            # Strip whitespace
            v = v.strip()
            if len(v) < 3:
                raise ValueError("Username must be at least 3 characters")
            # Basic alphanumeric + underscore validation
            if not v.replace("_", "").replace("-", "").isalnum():
                raise ValueError("Username can only contain letters, numbers, hyphens, and underscores")
        return v
    
    @field_validator("storefront")
    @classmethod
    def validate_storefront(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v = v.lower().strip()
            if len(v) < 2:
                raise ValueError("Storefront code must be at least 2 characters")
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "username": "music_lover_42",
                "music_provider": "apple",
                "storefront": "us"
            }
        }