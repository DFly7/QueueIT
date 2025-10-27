# app/schemas/user.py
from pydantic import BaseModel, Field
import uuid
from typing import Optional

class User(BaseModel):
    """
    Standard response schema for a user.
    Hides sensitive data and foreign keys.
    """
    id: uuid.UUID = Field(..., description="User ID")
    username: Optional[str] = Field(None, description="Username")

    class Config:
        from_attributes = True
        populate_by_name = True 
        
        json_schema_extra = {
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "username": "john_doe"
            }
        }