from __future__ import annotations

from typing import Optional, Dict, Any, List, Tuple

from supabase import Client
import structlog

logger = structlog.get_logger(__name__)


class QueueRepository:
    """
    Data access for 'queued_songs' and 'votes'.
    Provides helpers to add to queue, list queue with aggregated votes,
    read a queued song, and cast/change a vote.
    """

    def __init__(self, client: Client):
        self.client = client

    # --- Queued songs ---
    def add_song_to_queue(
        self,
        *,
        session_id: str,
        added_by_id: str,
        song_external_id: str,
        status: str = "queued",
    ) -> Dict[str, Any]:
        response = (
            self.client
            .from_("queued_songs")
            .insert(
                {
                    "session_id": session_id,
                    "added_by_id": added_by_id,
                    "status": status,
                    "song_external_id": song_external_id,
                    # New songs start at 0 votes and are treated as "gainers"
                    # so they sort to the bottom of the 0-vote tier (behind stable songs).
                    "entered_tier_by_gain": True,
                },
                returning="representation"
            )
            .execute()
        )
        if response.data is None:
            raise ValueError("Failed to insert queued song")
        return response.data[0] # <-- This returns the DICTIONARY   

    def get_queued_song(self, queued_song_id: str) -> Optional[Dict[str, Any]]:
        response = (
            self.client
            .from_("queued_songs")
            .select("*")
            .eq("id", queued_song_id)
            .maybe_single()
            .execute()
        )
        return response.data

    def get_next_queued_song(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        Get the next song in the queue (highest votes, then oldest).
        Only returns songs with status='queued'.
        """
        queue_items = self.list_session_queue(session_id)
        # Filter for only queued songs (not playing, played, or skipped)
        queued_items = [item for item in queue_items if item["status"] == "queued"]
        return queued_items[0] if queued_items else None

    def update_song_status(self, queued_song_id: str, new_status: str) -> Dict[str, Any]:
        """
        Update the status of a queued song.
        """
        response = (
            self.client
            .from_("queued_songs")
            .update({"status": new_status}, returning="representation")
            .eq("id", queued_song_id)
            .execute()
        )
        if not response.data:
            raise ValueError(f"Failed to update status for queued_song {queued_song_id}")
        return response.data[0]

    def list_session_queue(self, session_id: str) -> List[Dict[str, Any]]:
        """
        Returns a list of queue items for the given session, each augmented with:
        - song (from 'songs')
        - added_by (from 'users')
        - votes (sum of vote_value from 'votes')

        Sort order (asymmetric tier sort):
          1. votes DESC — higher-voted songs first
          2. entered_tier_by_gain ASC — losers (False) before gainers (True)
          3. Within losers: last_entered_tier_at DESC — most recent loss at top
             Within gainers: last_entered_tier_at ASC — oldest gain first (newest at bottom)
          4. added_at ASC — tie-breaker: earlier added song wins
        """
        queued_resp = (
            self.client
            .from_("queued_songs")
            .select("*")
            .eq("session_id", session_id)
            .order("created_at", desc=False)
            .execute()
        )
        queued_rows: List[Dict[str, Any]] = queued_resp.data or []
        if not queued_rows:
            return []

        # Collect ids for batch fetches
        song_ids = {row["song_external_id"] for row in queued_rows}
        user_ids = {row["added_by_id"] for row in queued_rows}
        queued_ids = {row["id"] for row in queued_rows}

        songs_by_id = self._fetch_songs_map(song_ids)
        users_by_id = self._fetch_users_map(user_ids)
        votes_sum_by_queued = self._fetch_votes_sum_map(queued_ids)

        # Build view rows — include tier metadata from the DB row.
        # Note: the live DB column is "created_at"; we expose it as "added_at" in the view.
        view_rows: List[Dict[str, Any]] = []
        for row in queued_rows:
            view_rows.append(
                {
                    "id": row["id"],
                    "status": row["status"],
                    "added_at": row["created_at"],
                    "votes": votes_sum_by_queued.get(row["id"], 0),
                    "song": songs_by_id.get(row["song_external_id"]),
                    "added_by": users_by_id.get(row["added_by_id"]),
                    "last_entered_tier_at": row.get("last_entered_tier_at"),
                    "entered_tier_by_gain": row.get("entered_tier_by_gain", True),
                }
            )

        def _tier_sort_key(r: Dict[str, Any]) -> tuple:
            votes = -int(r["votes"])
            by_gain: bool = r.get("entered_tier_by_gain", True)
            ts = r.get("last_entered_tier_at") or r["added_at"]
            ts_val: float = ts.timestamp() if hasattr(ts, "timestamp") else 0.0
            # Losers (by_gain=False): most recent at top → negate ts so DESC
            # Gainers (by_gain=True): most recent at bottom → leave ts ascending
            secondary = ts_val if by_gain else -ts_val
            return (votes, by_gain, secondary, r["added_at"])

        view_rows.sort(key=_tier_sort_key)
        return view_rows

    # --- User vote hydration ---
    def get_user_votes_for_session(self, *, session_id: str, user_id: str) -> Dict[str, int]:
        """
        Returns {queued_song_id: vote_value} for all songs the user has voted on
        in the given session. Uses a PostgreSQL RPC for an efficient single-JOIN
        query; SECURITY INVOKER ensures existing RLS policies still apply.
        """
        resp = self.client.rpc(
            "get_user_votes_for_session",
            {"p_session_id": session_id, "p_user_id": user_id},
        ).execute()
        rows: List[Dict[str, Any]] = resp.data or []
        return {str(r["queued_song_id"]): int(r["vote_value"]) for r in rows}

    # --- Voting ---
    def vote_on_song(self, *, queued_song_id: str, user_id: str, vote_value: int) -> Dict[str, Any]:
        """
        Casts or changes a user's vote for a queued song using a single upsert.
        Returns the updated vote row and the new aggregate sum for that queued song.
        """
        
        # This one call handles both creating a new vote and updating an old one.
        vote_resp = (
            self.client
            .from_("votes")
            .upsert(
                {
                    "queued_song_id": queued_song_id,
                    "user_id": user_id,
                    "vote_value": vote_value,
                },
                on_conflict="queued_song_id, user_id",  # <-- IMPORTANT: See step 2
                returning="representation"
            )
            .execute()
        )

        # Check for RLS errors or other failures
        if vote_resp.data is None:
            raise ValueError(f"Failed to upsert vote. RLS may have blocked the request. Error: {vote_resp.error}")

        # Compute new total - use lowercase to match Supabase UUID format
        total = self._fetch_votes_sum_map({queued_song_id}).get(queued_song_id.lower(), 0)
        return {"vote": vote_resp.data, "total_votes": int(total)}

    def remove_vote(self, *, queued_song_id: str, user_id: str) -> Dict[str, Any]:
        """
        Removes a user's vote from a queued song.
        Returns the new aggregate sum for that queued song.
        """
        delete_resp = (
            self.client
            .from_("votes")
            .delete()
            .eq("queued_song_id", queued_song_id)
            .eq("user_id", user_id)
            .execute()
        )

        # Compute new total after deletion
        total = self._fetch_votes_sum_map({queued_song_id}).get(queued_song_id.lower(), 0)
        return {"total_votes": int(total)}

    # --- Internal batch helpers ---
    def _fetch_songs_map(self, external_ids: set[str]) -> Dict[str, Dict[str, Any]]:
        if not external_ids:
            return {}
        ids_list = list(external_ids)
        resp = (
            self.client
            .from_("songs")
            .select("*")
            .in_("external_id", ids_list)
            .execute()
        )
        rows: List[Dict[str, Any]] = resp.data or []
        return {row["external_id"]: row for row in rows}

    def _fetch_users_map(self, user_ids: set[str]) -> Dict[str, Dict[str, Any]]:
        if not user_ids:
            return {}
        ids_list = list(user_ids)
        resp = (
            self.client
            .from_("users")
            .select("id, username, is_anonymous")
            .in_("id", ids_list)
            .execute()
        )
        rows: List[Dict[str, Any]] = resp.data or []
        return {row["id"]: row for row in rows}

    def _fetch_votes_sum_map(self, queued_ids: set[str]) -> Dict[str, int]:
        if not queued_ids:
            return {}
        ids_list = list(queued_ids)
        logger.debug("fetching_votes_sum", queued_ids=ids_list)
        resp = (
            self.client
            .from_("votes")
            .select("queued_song_id, vote_value")
            .in_("queued_song_id", ids_list)
            .execute()
        )
        rows: List[Dict[str, Any]] = resp.data or []
        totals: Dict[str, int] = {}
        for row in rows:
            qid = row["queued_song_id"]
            totals[qid] = int(totals.get(qid, 0)) + int(row.get("vote_value", 0))
        logger.debug("votes_sum_computed", vote_count=len(rows), totals=totals)
        return totals


