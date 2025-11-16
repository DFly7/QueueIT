from __future__ import annotations

from typing import Optional, Dict, Any, List, Tuple

from supabase import Client


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
        song_spotify_id: str,
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
                    "song_spotify_id": song_spotify_id,
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

    def list_session_queue(self, session_id: str) -> List[Dict[str, Any]]:
        """
        Returns a list of queue items for the given session, each augmented with:
        - song (from 'songs')
        - added_by (from 'users')
        - votes (sum of vote_value from 'votes')
        Sorted by votes desc, created_at asc.
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
        song_ids = {row["song_spotify_id"] for row in queued_rows}
        user_ids = {row["added_by_id"] for row in queued_rows}
        queued_ids = {row["id"] for row in queued_rows}

        songs_by_id = self._fetch_songs_map(song_ids)
        users_by_id = self._fetch_users_map(user_ids)
        votes_sum_by_queued = self._fetch_votes_sum_map(queued_ids)

        # Build view rows
        view_rows: List[Dict[str, Any]] = []
        for row in queued_rows:
            view_rows.append(
                {
                    "id": row["id"],
                    "status": row["status"],
                    "added_at": row["created_at"],
                    "votes": votes_sum_by_queued.get(row["id"], 0),
                    "song": songs_by_id.get(row["song_spotify_id"]),
                    "added_by": users_by_id.get(row["added_by_id"]),
                }
            )

        # Sort by votes desc, then created_at asc
        view_rows.sort(key=lambda r: (-int(r["votes"]), r["added_at"]))
        return view_rows

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

        # Compute new total
        total = self._fetch_votes_sum_map({queued_song_id}).get(queued_song_id, 0)
        return {"vote": vote_resp.data, "total_votes": int(total)}

    # --- Internal batch helpers ---
    def _fetch_songs_map(self, spotify_ids: set[str]) -> Dict[str, Dict[str, Any]]:
        if not spotify_ids:
            return {}
        ids_list = list(spotify_ids)
        resp = (
            self.client
            .from_("songs")
            .select("*")
            .in_("spotify_id", ids_list)
            .execute()
        )
        rows: List[Dict[str, Any]] = resp.data or []
        return {row["spotify_id"]: row for row in rows}

    def _fetch_users_map(self, user_ids: set[str]) -> Dict[str, Dict[str, Any]]:
        if not user_ids:
            return {}
        ids_list = list(user_ids)
        resp = (
            self.client
            .from_("users")
            .select("id, username")
            .in_("id", ids_list)
            .execute()
        )
        rows: List[Dict[str, Any]] = resp.data or []
        return {row["id"]: row for row in rows}

    def _fetch_votes_sum_map(self, queued_ids: set[str]) -> Dict[str, int]:
        if not queued_ids:
            return {}
        ids_list = list(queued_ids)
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
        return totals


