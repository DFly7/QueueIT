from typing import Optional, Dict, Any

from supabase import Client

from app.utils.log_context import log_db_operation


class SongRepository:
    """
    Data access for the 'songs' catalog table.
    """

    def __init__(self, client: Client):
        self.client = client

    def get_by_spotify_id(self, spotify_id: str) -> Optional[Dict[str, Any]]:
        response = log_db_operation(
            operation="songs.get_by_spotify_id",
            table="songs",
            params={"spotify_id": spotify_id},
            executor=lambda: (
                self.client.from_("songs")
                .select("*")
                .eq("spotify_id", spotify_id)
                .maybe_single()
                .execute()
            ),
        )
        return response.data

    def upsert_song(
        self,
        *,
        spotify_id: str,
        name: str,
        artist: str,
        album: str,
        durationMSs: int,
        image_url: str,
        isrc_identifier: str,
    ) -> Dict[str, Any]:
        """
        Ensures the song exists in 'songs' table.
        Returns the row after upsert.
        """
        response = log_db_operation(
            operation="songs.upsert",
            table="songs",
            params={"spotify_id": spotify_id},
            executor=lambda: (
                self.client.from_("songs")
                .upsert(
                    {
                        "spotify_id": spotify_id,
                        "name": name,
                        "artist": artist,
                        "album": album,
                        "durationMSs": durationMSs,
                        "image_url": image_url,
                        "isrc_identifier": isrc_identifier,
                    },
                    on_conflict="spotify_id",
                    ignore_duplicates=False,
                    returning="representation",
                )
                .execute()
            ),
        )
        if response.data is None:
            raise ValueError(f"Failed to upsert song {spotify_id}")
        return response.data


