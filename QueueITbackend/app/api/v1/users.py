"""
User Profile API Endpoints

Handles user profile management (username, music provider, storefront).
"""

from fastapi import APIRouter, Depends, HTTPException
from app.core.auth import get_authenticated_client, AuthenticatedClient
from app.core.config import get_settings
from app.repositories.user_repo import UserRepository, delete_account
from app.schemas.user import User, UserProfileUpdate
from app.logging_config import get_logger

logger = get_logger(__name__)

router = APIRouter(tags=["users"])


@router.get("/me", response_model=User)
async def get_current_user_profile(
    auth: AuthenticatedClient = Depends(get_authenticated_client)
) -> User:
    """
    Get current authenticated user's profile.
    
    Returns user data including username, music_provider, and storefront.
    """
    user_id = auth.payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    
    user_repo = UserRepository(auth.client)
    user_data = user_repo.get_by_id(user_id)
    
    if not user_data:
        raise HTTPException(status_code=404, detail="User not found")
    
    logger.info("Fetched user profile", extra={"user_id": user_id})
    
    return User(**user_data)


@router.patch("/me", response_model=User)
async def update_current_user_profile(
    profile_update: UserProfileUpdate,
    auth: AuthenticatedClient = Depends(get_authenticated_client)
) -> User:
    """
    Update current authenticated user's profile.
    
    Allows updating:
    - username (3-30 characters, alphanumeric + underscore/hyphen)
    - music_provider (apple, spotify, none)
    - storefront (Apple Music region code, e.g., 'us', 'gb', 'ca')
    
    All fields are optional - only provided fields will be updated.
    """
    user_id = auth.payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    
    user_repo = UserRepository(auth.client)
    
    # Check if user exists
    existing_user = user_repo.get_by_id(user_id)
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check for username uniqueness if username is being updated
    if profile_update.username and profile_update.username != existing_user.get("username"):
        try:
            # Query to check if username already exists
            response = (
                auth.client
                .from_("users")
                .select("id")
                .eq("username", profile_update.username)
                .maybe_single()
                .execute()
            )
            if response and response.data:
                raise HTTPException(status_code=400, detail="Username already taken")
        except HTTPException:
            # Re-raise HTTP exceptions (like duplicate username)
            raise
        except Exception as e:
            logger.error("Failed to check username uniqueness", extra={
                "username": profile_update.username,
                "error": str(e)
            })
            # Continue anyway - better to allow the update than block the user
    
    try:
        updated_user = user_repo.update_profile(
            user_id=user_id,
            username=profile_update.username,
            music_provider=profile_update.music_provider,
            storefront=profile_update.storefront
        )
        
        logger.info("Updated user profile", extra={
            "user_id": user_id,
            "updated_fields": profile_update.model_dump(exclude_none=True)
        })
        
        return User(**updated_user)
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        error_str = str(e)
        logger.error("Failed to update user profile", extra={
            "user_id": user_id,
            "error": error_str
        })
        
        # Check for duplicate username constraint violation
        if "users_username_key" in error_str or "duplicate key" in error_str.lower():
            raise HTTPException(status_code=400, detail="Username already taken")
        
        raise HTTPException(status_code=500, detail="Failed to update profile")


@router.delete("/me", status_code=204)
async def delete_current_user_account(
    auth: AuthenticatedClient = Depends(get_authenticated_client)
) -> None:
    user_id = auth.payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid authentication token")

    settings = get_settings()
    if not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Account deletion is not available at this time")

    try:
        delete_account(user_id)
        logger.info("Deleted user account", extra={"user_id": user_id})
    except Exception as e:
        logger.error("Failed to delete account", extra={"user_id": user_id, "error": str(e)})
        raise HTTPException(status_code=500, detail="Failed to delete account")
