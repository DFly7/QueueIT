from typing import Any, Dict, Optional

from supabase import Client


class SkipRequestRepository:
    """
    Data access for the 'skip_requests' table.
    Uses SECURITY DEFINER RPCs for operations that need to bypass RLS
    (counting participants, clearing all requests on song advance).
    """

    def __init__(self, client: Client):
        self.client = client

    def insert_request(self, *, session_id: str, user_id: str) -> bool:
        """
        Insert a skip request for (session_id, user_id).
        Silently ignores duplicates via ON CONFLICT DO NOTHING.
        Returns True if a new row was inserted, False if already existed.
        """
        response = (
            self.client
            .from_("skip_requests")
            .upsert(
                {"session_id": session_id, "user_id": user_id},
                on_conflict="session_id,user_id",
                ignore_duplicates=True,
            )
            .execute()
        )
        return bool(response.data)

    def get_skip_request_count(self, session_id: str) -> int:
        """
        Returns the current number of skip requests for a session.
        Uses SECURITY DEFINER RPC to bypass RLS restrictions.
        """
        response = self.client.rpc(
            "get_session_skip_request_count",
            {"p_session_id": session_id},
        ).execute()
        return response.data or 0

    def get_participant_count(self, session_id: str) -> int:
        """
        Returns how many users are currently in the session.
        Uses SECURITY DEFINER RPC to bypass RLS restrictions.
        """
        response = self.client.rpc(
            "get_session_participant_count",
            {"p_session_id": session_id},
        ).execute()
        return response.data or 1  # default 1 to avoid division by zero

    def user_has_requested_skip(self, *, session_id: str, user_id: str) -> bool:
        """Returns True if the user already has an active skip request."""
        response = self.client.rpc(
            "user_has_skip_request",
            {"p_session_id": session_id, "p_user_id": user_id},
        ).execute()
        return bool(response.data)

    def clear_skip_requests(self, session_id: str) -> None:
        """
        Deletes all skip requests for a session.
        Called whenever a song advances (host skip, song_finished, or crowdsourced skip).
        Uses SECURITY DEFINER RPC so the service-role action bypasses user RLS.
        """
        self.client.rpc(
            "clear_skip_requests",
            {"p_session_id": session_id},
        ).execute()

    def crowdsourced_skip_advance(self, session_id: str) -> Optional[str]:
        """
        Performs the full crowdsourced-skip advance atomically via a SECURITY DEFINER
        RPC, bypassing RLS for all required writes (queued_songs UPDATE, sessions UPDATE,
        skip_requests DELETE). Regular participants cannot perform these writes directly.

        Returns the new current queued_song id, or None if the queue is empty.
        """
        response = self.client.rpc(
            "crowdsourced_skip_advance",
            {"p_session_id": session_id},
        ).execute()
        return response.data or None
