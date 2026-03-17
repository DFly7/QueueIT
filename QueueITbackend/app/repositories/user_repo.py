from typing import Optional, Dict, Any

from supabase import Client, create_client


def delete_account(user_id: str) -> None:
    """
    Atomically delete all public data for a user then remove their auth record.
    Uses the service-role key to bypass RLS. Must only be called server-side.
    """
    from app.core.config import get_settings
    settings = get_settings()

    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise ValueError("Admin Supabase credentials not configured")

    admin_client = create_client(settings.supabase_url, settings.supabase_service_role_key)

    # Delete all public data atomically via SECURITY DEFINER function
    admin_client.rpc("delete_user_data", {"p_user_id": user_id}).execute()

    # Delete auth record (not covered by the DB function)
    admin_client.auth.admin.delete_user(user_id)


class UserRepository:
    """
    Data access for the 'users' table.
    """

    def __init__(self, client: Client):
        self.client = client

    def get_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        response = (
            self.client
            .from_("users")
            .select("*")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        return response.data

    def update_profile(
        self, 
        user_id: str, 
        username: Optional[str] = None,
        music_provider: Optional[str] = None,
        storefront: Optional[str] = None,
        spotify_refresh_token: Optional[str] = None
    ) -> Dict[str, Any]:
        """Update user profile fields"""
        update_data = {}
        
        if username is not None:
            update_data["username"] = username
        if music_provider is not None:
            update_data["music_provider"] = music_provider
        if storefront is not None:
            update_data["storefront"] = storefront
        if spotify_refresh_token is not None:
            update_data["spotify_refresh_token"] = spotify_refresh_token
            
        if not update_data:
            raise ValueError("No fields to update")
            
        response = (
            self.client
            .from_("users")
            .update(update_data, returning="representation")
            .eq("id", user_id)
            .execute()
        )
        
        if not response.data:
            raise ValueError("Failed to update user profile")
        return response.data[0]

    def set_current_session(self, *, user_id: str, session_id: Optional[str]) -> Dict[str, Any]:
        response = (
            self.client
            .from_("users")
            .update({"current_session": session_id}, returning="representation")
            .eq("id", user_id)
            .execute()
        )
        if not response.data:
            raise ValueError("Failed to set current_session for user")
        return response.data[0]

    def leave_session(self, *, user_id: str, session_id: str) -> None:
        """Clear current session and record it as previous_session_id atomically."""
        self.client.from_("users") \
            .update({"current_session": None, "previous_session_id": session_id}) \
            .eq("id", user_id) \
            .execute()


