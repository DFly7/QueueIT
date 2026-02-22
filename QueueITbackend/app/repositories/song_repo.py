from typing import Optional, Dict, Any

from supabase import Client


class SongRepository:
    """
    Data access for the 'songs' catalog table.
    """

    def __init__(self, client: Client):
        self.client = client

    def get_by_external_id(self, external_id: str) -> Optional[Dict[str, Any]]:
        response = (
            self.client
            .from_("songs")
            .select("*")
            .eq("external_id", external_id)
            .maybe_single()
            .execute()
        )
        return response.data

    def upsert_song(
        self,
        *,
        external_id: str,
        name: str,
        artist: str,
        album: str,
        durationMSs: int,
        image_url: str,
        isrc_identifier: str,
        source: str = "spotify",
    ) -> Dict[str, Any]:
        """
        Ensures the song exists in 'songs' table.
        Returns the row after upsert.
        """
        response = (
            self.client
            .from_("songs")
            .upsert(
                {
                    "external_id": external_id,
                    "name": name,
                    "artist": artist,
                    "album": album,
                    "durationMSs": durationMSs,
                    "image_url": image_url,
                    "isrc_identifier": isrc_identifier,
                    "source": source,
                },
                on_conflict="external_id",
                ignore_duplicates=False,
                returning="representation" 
            )
            .execute()
        )
        if response.data is None:
            raise ValueError(f"Failed to upsert song {external_id}")
        return response.data


