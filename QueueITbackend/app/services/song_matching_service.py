"""
Song Matching Service

Handles cross-catalog song resolution between Spotify and Apple Music.
Uses ISRC as the "golden key" with fuzzy metadata fallback.
"""

import asyncio
import httpx
from typing import Optional, Tuple
from app.services.apple_music_service import get_apple_music_service
from app.services.spotify_service import _get_access_token
from app.logging_config import get_logger

logger = get_logger(__name__)


class SongMatchingService:
    """Service for resolving songs across music catalogs"""
    
    # Duration tolerance: ±3 seconds for fuzzy matching
    DURATION_TOLERANCE_MS = 3000
    
    async def get_spotify_track_metadata(self, spotify_id: str) -> Optional[dict]:
        """
        Fetch full track metadata from Spotify API.
        
        Args:
            spotify_id: Spotify track ID
            
        Returns:
            Track metadata dict or None if not found
        """
        try:
            token = _get_access_token()
            url = f"https://api.spotify.com/v1/tracks/{spotify_id}"
            
            headers = {"Authorization": f"Bearer {token}"}
            
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=headers, timeout=10.0)
                response.raise_for_status()
                
                track = response.json()
                logger.info("Fetched Spotify track metadata", extra={
                    "spotify_id": spotify_id,
                    "name": track.get("name"),
                    "isrc": track.get("external_ids", {}).get("isrc")
                })
                return track
                
        except Exception as e:
            logger.error("Failed to fetch Spotify track", extra={
                "spotify_id": spotify_id,
                "error": str(e)
            })
            return None
    
    async def resolve_spotify_to_apple(
        self,
        spotify_id: str,
        storefront: str = "us"
    ) -> Optional[Tuple[str, str]]:
        """
        Resolve a Spotify track to Apple Music catalog.
        
        Hierarchy:
        1. ISRC matching with album name preference (high confidence ~95%)
        2. Fuzzy metadata search with duration validation (medium confidence)
        3. Return None if no match
        
        Args:
            spotify_id: Spotify track ID
            storefront: Apple Music storefront/region
            
        Returns:
            Tuple of (apple_music_id, match_method) or None if no match
        """
        # Step 0: Get Spotify track metadata
        spotify_track = await self.get_spotify_track_metadata(spotify_id)
        if not spotify_track:
            logger.warning("Cannot resolve - Spotify track not found", extra={
                "spotify_id": spotify_id
            })
            return None
        
        artist = spotify_track["artists"][0]["name"] if spotify_track.get("artists") else "Unknown"
        title = spotify_track.get("name", "Unknown")
        duration_ms = spotify_track.get("duration_ms", 0)
        isrc = spotify_track.get("external_ids", {}).get("isrc")
        spotify_album = spotify_track.get("album", {}).get("name", "")
        spotify_album_track_count = spotify_track.get("album", {}).get("total_tracks", 0)
        
        apple_service = get_apple_music_service()
        
        # Step A: ISRC Matching (High Confidence)
        if isrc:
            logger.info("Attempting ISRC match", extra={
                "isrc": isrc,
                "spotify_id": spotify_id,
                "spotify_album": spotify_album,
                "spotify_track_count": spotify_album_track_count,
                "storefront": storefront
            })
            
            apple_song = await apple_service.search_by_isrc(
                isrc, 
                storefront, 
                spotify_album,
                spotify_album_track_count
            )
            if apple_song:
                apple_id = apple_song["id"]
                apple_album = apple_song.get("attributes", {}).get("albumName", "")
                logger.info("✅ ISRC match successful", extra={
                    "spotify_id": spotify_id,
                    "apple_id": apple_id,
                    "spotify_album": spotify_album,
                    "apple_album": apple_album,
                    "method": "isrc"
                })
                return (apple_id, "isrc")
        else:
            logger.debug("No ISRC available for Spotify track", extra={
                "spotify_id": spotify_id
            })
        
        # Step B: Fuzzy Metadata Matching (Medium Confidence)
        logger.info("Attempting fuzzy metadata match", extra={
            "artist": artist,
            "title": title,
            "storefront": storefront
        })
        
        apple_results = await apple_service.search_by_metadata(
            artist=artist,
            title=title,
            storefront=storefront,
            limit=10
        )
        
        # Validate results by duration
        for apple_song in apple_results:
            attrs = apple_song.get("attributes", {})
            apple_duration_ms = attrs.get("durationInMillis", 0)
            apple_artist = attrs.get("artistName", "")
            apple_title = attrs.get("name", "")
            
            duration_diff = abs(apple_duration_ms - duration_ms)
            
            if duration_diff <= self.DURATION_TOLERANCE_MS:
                apple_id = apple_song["id"]
                logger.info("✅ Fuzzy match successful", extra={
                    "spotify_id": spotify_id,
                    "apple_id": apple_id,
                    "method": "fuzzy",
                    "duration_diff_ms": duration_diff,
                    "spotify_track": f"{artist} - {title}",
                    "apple_track": f"{apple_artist} - {apple_title}"
                })
                return (apple_id, "fuzzy")
        
        # Step C: No Match Found
        logger.warning("❌ No Apple Music match found", extra={
            "spotify_id": spotify_id,
            "artist": artist,
            "title": title,
            "storefront": storefront,
            "attempted_methods": ["isrc", "fuzzy"]
        })
        return None
    
    async def extract_apple_music_track_data(self, apple_id: str, storefront: str = "us") -> Optional[dict]:
        """
        Extract standardized track data from Apple Music.
        
        Args:
            apple_id: Apple Music catalog ID
            storefront: Apple Music storefront/region
            
        Returns:
            Standardized track dict or None
        """
        try:
            apple_service = get_apple_music_service()
            token = apple_service.get_token()
            
            url = f"{apple_service.BASE_URL}/catalog/{storefront}/songs/{apple_id}"
            headers = {"Authorization": f"Bearer {token}"}
            
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=headers, timeout=10.0)
                response.raise_for_status()
                
                data = response.json()
                song = data.get("data", [])[0] if data.get("data") else None
                
                if not song:
                    return None
                
                attrs = song.get("attributes", {})
                
                # Extract standardized data
                track_data = {
                    "external_id": apple_id,
                    "name": attrs.get("name", "Unknown"),
                    "artist": attrs.get("artistName", "Unknown"),
                    "album": attrs.get("albumName", "Unknown"),
                    "duration_ms": attrs.get("durationInMillis", 0),
                    "image_url": attrs.get("artwork", {}).get("url", "").replace("{w}x{h}", "300x300"),
                    "isrc": attrs.get("isrc", ""),
                    "source": "apple_music"
                }
                
                return track_data
                
        except Exception as e:
            logger.error("Failed to extract Apple Music track data", extra={
                "apple_id": apple_id,
                "error": str(e)
            })
            return None


def get_song_matching_service() -> SongMatchingService:
    """Get song matching service instance"""
    return SongMatchingService()
