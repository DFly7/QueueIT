from typing import Optional, Dict, Any

from supabase import Client


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

    def set_current_session(self, *, user_id: str, session_id: Optional[str]) -> Dict[str, Any]:
        response = (
            self.client
            .from_("users")
            .update({"current_session": session_id})
            .eq("id", user_id)
            .select("*")
            .single()
            .execute()
        )
        if response.data is None:
            raise ValueError("Failed to set current_session for user")
        return response.data


