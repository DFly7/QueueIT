from typing import Optional, Dict, Any

from supabase import Client

from app.utils.log_context import log_db_operation


class SessionRepository:
    """
    Data access for the 'sessions' table.
    All queries run through a user-authenticated Supabase Client to respect RLS.
    """

    def __init__(self, client: Client):
        self.client = client

    # --- CRUD ---
    def create_session(self, *, host_id: str, join_code: str) -> Dict[str, Any]:
        """
        Inserts a new session. 'join_code' must be unique.
        Returns the inserted row.
        """
        try:
        response = log_db_operation(
            operation="sessions.create",
            table="sessions",
            params={"join_code": join_code, "host_id": host_id},
            executor=lambda: (
                self.client.from_("sessions")
                .insert(
                    {
                        "join_code": join_code,
                        "host_id": host_id,
                    },
                    returning="representation",
                )
                .execute()
            ),
        )
            if response.data is None:
                raise ValueError(f"Failed to create session: {response}")
        except Exception as e:
            raise ValueError(f"Failed to create session: {e}")
        return response.data[0] # <-- This returns the DICTIONARY

    def get_by_join_code(self, join_code: str) -> Optional[Dict[str, Any]]:
        response = log_db_operation(
            operation="sessions.get_by_join_code",
            table="sessions",
            params={"join_code": join_code},
            executor=lambda: (
                self.client.from_("sessions")
                .select("*")
                .eq("join_code", join_code)
                .maybe_single()
                .execute()
            ),
        )
        return response.data

    def get_by_id(self, session_id: str) -> Optional[Dict[str, Any]]:
        response = log_db_operation(
            operation="sessions.get_by_id",
            table="sessions",
            params={"session_id": session_id},
            executor=lambda: (
                self.client.from_("sessions")
                .select("*")
                .eq("id", session_id)
                .maybe_single()
                .execute()
            ),
        )
        return response.data

    def set_current_song(self, *, session_id: str, queued_song_id: Optional[str]) -> Dict[str, Any]:
        response = log_db_operation(
            operation="sessions.set_current_song",
            table="sessions",
            params={"session_id": session_id, "queued_song_id": queued_song_id},
            executor=lambda: (
                self.client.from_("sessions")
                .update({"current_song": queued_song_id}, returning="representation")
                .eq("id", session_id)
                .execute()
            ),
        )
        if not response.data:
            raise ValueError("Failed to update current song for session")
        return response.data[0]

    # --- Helpers ---
    def get_current_for_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Looks up the user's 'current_session' and returns that session if present.
        """
        user_resp = log_db_operation(
            operation="users.get_current_session",
            table="users",
            params={"user_id": user_id},
            executor=lambda: (
                self.client.from_("users")
                .select("current_session")
                .eq("id", user_id)
                .maybe_single()
                .execute()
            ),
        )
        if not user_resp.data or not user_resp.data.get("current_session"):
            return None
        session_id = user_resp.data["current_session"]
        return self.get_by_id(session_id)


