from typing import Optional, Dict, Any

from supabase import Client

from app.exceptions import DuplicateJoinCodeError


class SessionRepository:
    """
    Data access for the 'sessions' table.
    All queries run through a user-authenticated Supabase Client to respect RLS.
    """

    def __init__(self, client: Client):
        self.client = client

    # --- CRUD ---
    def create_session(self, *, host_id: str, join_code: str, host_provider: str = "spotify") -> Dict[str, Any]:
        """
        Inserts a new session. 'join_code' must be unique.
        Returns the inserted row.
        
        Args:
            host_id: User ID of the host
            join_code: Unique session join code
            host_provider: Music provider of the host ('apple' or 'spotify')
        """
        try:
            response = (
                self.client
                .from_("sessions")
                .insert(
                    {
                        "join_code": join_code,
                        "host_id": host_id,
                        "host_provider": host_provider,
                    },
                    returning="representation"  # <-- Use this parameter
                )
                .execute()
            )
            if response.data is None:
                raise ValueError(f"Failed to create session: {response}")
        except Exception as e:
            err_str = str(e).lower()
            if "23505" in str(e) or "duplicate key" in err_str:
                raise DuplicateJoinCodeError() from e
            raise ValueError(f"Failed to create session: {e}")
        return response.data[0] # <-- This returns the DICTIONARY

    def get_by_join_code(self, join_code: str) -> Optional[Dict[str, Any]]:
        response = (
            self.client
            .from_("sessions")
            .select("*")
            .eq("join_code", join_code)
            .maybe_single()
            .execute()
        )
        if response is None:
            return None
        return response.data

    def get_by_id(self, session_id: str) -> Optional[Dict[str, Any]]:
        response = (
            self.client
            .from_("sessions")
            .select("*")
            .eq("id", session_id)
            .maybe_single()
            .execute()
        )
        if response is None:
            return None
        return response.data

    def set_current_song(self, *, session_id: str, queued_song_id: Optional[str]) -> Dict[str, Any]:
        response = (
            self.client
            .from_("sessions")
            .update({"current_song": queued_song_id}, returning="representation")
            .eq("id", session_id)
            .execute()
        )
        if not response.data:
            raise ValueError("Failed to update current song for session")
        return response.data[0]

    def autoplay_first_song(self, *, session_id: str, queued_song_id: str) -> bool:
        """
        Atomically promotes queued_song_id to 'playing' and sets it as
        sessions.current_song, but only if current_song is currently NULL.

        Runs via a SECURITY DEFINER RPC so that guests (who lack UPDATE
        permission on sessions/queued_songs via RLS) can still trigger
        auto-play when they add the very first song.

        Returns True if the song was promoted, False if current_song was
        already set (i.e. another add beat us to it).
        """
        response = (
            self.client
            .rpc("autoplay_first_song", {
                "p_session_id": session_id,
                "p_queued_song_id": queued_song_id,
            })
            .execute()
        )
        return bool(response.data)

    def touch_session(self, session_id: str) -> None:
        """Bump last_presence_change to signal a participant count change to realtime subscribers.
        Uses a SECURITY DEFINER RPC so any session member (not just the host) can trigger the
        CDC event — direct UPDATE on sessions is blocked by sessions_update_host RLS for guests."""
        self.client.rpc("touch_session_presence", {"p_session_id": session_id}).execute()

    # --- Helpers ---
    def get_current_for_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Looks up the user's 'current_session' and returns that session if present.
        """
        user_resp = (
            self.client
            .from_("users")
            .select("current_session")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        if not user_resp.data or not user_resp.data.get("current_session"):
            return None
        session_id = user_resp.data["current_session"]
        return self.get_by_id(session_id)


