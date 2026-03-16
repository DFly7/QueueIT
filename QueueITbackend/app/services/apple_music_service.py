"""
Apple Music API Service

Handles Apple Music Developer Token generation and API calls.
Uses private key to generate JWT for server-to-server authentication.
"""

import base64
import time
import jwt
import httpx
from functools import lru_cache
from pathlib import Path
from typing import Optional
from difflib import SequenceMatcher

from app.core.config import get_settings
from app.logging_config import get_logger

logger = get_logger(__name__)


def _string_similarity(a: str, b: str) -> float:
    """Calculate string similarity (0.0 to 1.0) using SequenceMatcher"""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def _is_compilation_album(album_name: str) -> bool:
    """Detect if album is likely a compilation/various artists album"""
    album_lower = album_name.lower()
    compilation_patterns = [
        "now that's what i call",
        "greatest hits",
        "best of",
        "the best of",
        "hits",
        "collection",
        "anthology",
        "various artists",
        "va -",
        "compilation",
        "essentials",
        "classics",
        "ultimate",
        "complete",
        "top 40",
        "chart",
        "ministry of sound",
        # Generic playlist/compilation patterns
        "music 20",  # Breakfast Music 2026, Happy Café Music, etc.
        "songs 20",  # Wedding Songs 2026, etc.
        "hits 20",   # Hits 2026, etc.
        "vibes 20",  # Happy Vibes 2026, etc.
        "club",      # GIRLS CLUB, Kids Club, etc.
        "party 20",  # Bridal Party 2026, etc.
        "morning",   # Morning Glow, Spring Morning, etc.
        "coffeehouse",
        "café music",
        "study motivation",
        "workout",
        "romantic",
        "love songs",
        "feel good",
        "chill",
        "relax"
    ]
    return any(pattern in album_lower for pattern in compilation_patterns)


class AppleMusicService:
    """Service for Apple Music API operations"""
    
    BASE_URL = "https://api.music.apple.com/v1"
    TOKEN_EXPIRY = 15777000  # 6 months in seconds (Apple's max)
    
    def __init__(self):
        self.settings = get_settings()
        self._token: Optional[str] = None
        self._token_expires_at: float = 0
        
    def _load_private_key(self) -> str:
        """Load Apple Music private key.

        Prefers APPLE_PRIVATE_KEY_BASE64 (base64-encoded .p8 content stored as an
        env var — the safe pattern for cloud deployments like Railway where binary
        files cannot be committed to the repo).  Falls back to APPLE_PRIVATE_KEY_PATH
        for local development where the file lives in certs/.
        """
        if self.settings.apple_private_key_base64:
            logger.debug("Loading Apple Music private key from APPLE_PRIVATE_KEY_BASE64")
            return base64.b64decode(self.settings.apple_private_key_base64).decode("utf-8")

        if not self.settings.apple_private_key_path:
            raise ValueError(
                "Apple Music private key not configured. "
                "Set APPLE_PRIVATE_KEY_BASE64 (production) or APPLE_PRIVATE_KEY_PATH (local dev)."
            )

        key_path = Path(self.settings.apple_private_key_path)
        if not key_path.is_absolute():
            key_path = Path(__file__).parent.parent.parent / key_path

        if not key_path.exists():
            raise FileNotFoundError(f"Apple Music private key not found: {key_path}")

        logger.debug("Loading Apple Music private key from file", extra={"path": str(key_path)})
        with open(key_path, "r") as f:
            return f.read()

    def _generate_token(self) -> str:
        """Generate Apple Music Developer Token (JWT)"""
        has_key = self.settings.apple_private_key_base64 or self.settings.apple_private_key_path
        if not all([self.settings.apple_team_id, self.settings.apple_key_id, has_key]):
            raise ValueError("Apple Music credentials not fully configured")
        
        private_key = self._load_private_key()
        
        headers = {
            "alg": "ES256",
            "kid": self.settings.apple_key_id
        }
        
        payload = {
            "iss": self.settings.apple_team_id,
            "iat": int(time.time()),
            "exp": int(time.time()) + self.TOKEN_EXPIRY
        }
        
        token = jwt.encode(
            payload,
            private_key,
            algorithm="ES256",
            headers=headers
        )
        
        logger.info("Generated new Apple Music Developer Token", extra={
            "expires_in_days": self.TOKEN_EXPIRY / 86400
        })
        
        return token
    
    def get_token(self) -> str:
        """Get valid Apple Music Developer Token (cached)"""
        current_time = time.time()
        
        # Refresh if token doesn't exist or expires in < 1 day
        if not self._token or current_time >= (self._token_expires_at - 86400):
            self._token = self._generate_token()
            self._token_expires_at = current_time + self.TOKEN_EXPIRY
            
        return self._token
    
    async def search_by_isrc(
        self,
        isrc: str,
        storefront: str = "us",
        preferred_album: Optional[str] = None,
        spotify_track_count: Optional[int] = None
    ) -> Optional[dict]:
        """
        Search Apple Music catalog by ISRC with intelligent version selection.
        
        When multiple versions exist, uses scoring system:
        - Exact album match: +100 points
        - Fuzzy album match (>0.8 similarity): +50 points  
        - Track count match (single vs album): +30 points
        - Prefer singles over albums: +20 points if both are singles
        
        Args:
            isrc: International Standard Recording Code
            storefront: Apple Music storefront/region (e.g., 'us', 'gb', 'ca')
            preferred_album: Optional album name to prefer when multiple versions exist
            spotify_track_count: Number of tracks in Spotify album (for single detection)
            
        Returns:
            Song data dict or None if not found
        """
        token = self.get_token()
        url = f"{self.BASE_URL}/catalog/{storefront}/songs"
        
        headers = {
            "Authorization": f"Bearer {token}"
        }
        
        params = {
            "filter[isrc]": isrc
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers, params=params, timeout=10.0)
                response.raise_for_status()
                
                data = response.json()
                results = data.get("data", [])
                
                if not results:
                    logger.debug("No Apple Music match for ISRC", extra={"isrc": isrc})
                    return None
                
                if len(results) == 1:
                    # Only one version, return it
                    song = results[0]
                    logger.info("Found Apple Music track by ISRC (single version)", extra={
                        "isrc": isrc,
                        "apple_id": song["id"],
                        "name": song["attributes"].get("name"),
                        "album": song["attributes"].get("albumName")
                    })
                    return song
                
                # Multiple versions exist - use scoring system
                logger.info("Multiple Apple Music versions found for ISRC", extra={
                    "isrc": isrc,
                    "count": len(results),
                    "albums": [r.get("attributes", {}).get("albumName") for r in results],
                    "track_counts": [r.get("attributes", {}).get("trackCount") for r in results],
                    "spotify_album": preferred_album,
                    "spotify_track_count": spotify_track_count
                })
                
                scored_results = []
                spotify_is_single = spotify_track_count and spotify_track_count <= 3
                
                for result in results:
                    attrs = result.get("attributes", {})
                    apple_album = attrs.get("albumName", "")
                    apple_track_count = attrs.get("trackCount", 0)
                    apple_is_single = apple_track_count <= 3
                    apple_is_compilation = _is_compilation_album(apple_album)
                    
                    score = 0
                    match_reasons = []
                    
                    # PENALTY: Compilation albums (unless Spotify album is also a compilation)
                    if apple_is_compilation:
                        if preferred_album and not _is_compilation_album(preferred_album):
                            score -= 100  # Heavy penalty for compilations when Spotify showed original
                            match_reasons.append("compilation_penalty")
                        else:
                            match_reasons.append("compilation_match")
                    else:
                        # BOOST: Non-compilation albums (prefer originals)
                        score += 40
                        match_reasons.append("original_release")
                    
                    # Album name matching
                    if preferred_album:
                        if apple_album.lower() == preferred_album.lower():
                            score += 100
                            match_reasons.append("exact_album")
                        else:
                            similarity = _string_similarity(apple_album, preferred_album)
                            if similarity > 0.8:
                                score += int(50 * similarity)
                                match_reasons.append(f"fuzzy_album_{similarity:.2f}")
                            elif similarity > 0.5:
                                # Weak match still gets some points
                                score += int(25 * similarity)
                                match_reasons.append(f"weak_album_{similarity:.2f}")
                    
                    # Track count matching (single vs album)
                    if spotify_track_count and apple_track_count:
                        if spotify_is_single == apple_is_single:
                            score += 30
                            match_reasons.append("track_count_type_match")
                    
                    # Prefer singles when Spotify shows a single
                    if spotify_is_single and apple_is_single:
                        score += 20
                        match_reasons.append("both_singles")
                    
                    scored_results.append({
                        "result": result,
                        "score": score,
                        "reasons": match_reasons,
                        "album": apple_album,
                        "track_count": apple_track_count,
                        "is_single": apple_is_single,
                        "is_compilation": apple_is_compilation
                    })
                
                # Sort by score descending
                scored_results.sort(key=lambda x: x["score"], reverse=True)
                
                best_match = scored_results[0]
                
                # Log all scores if we have many results or if best match is low scoring
                log_all = len(results) > 10 or best_match["score"] < 100
                logger.info("Selected best Apple Music match", extra={
                    "isrc": isrc,
                    "apple_id": best_match["result"]["id"],
                    "name": best_match["result"]["attributes"].get("name"),
                    "album": best_match["album"],
                    "score": best_match["score"],
                    "reasons": best_match["reasons"],
                    "all_scores": [(s["album"], s["score"], s["reasons"]) for s in (scored_results if log_all else scored_results[:3])]
                })
                
                return best_match["result"]
                    
            except httpx.HTTPStatusError as e:
                logger.error("Apple Music API error", extra={
                    "status": e.response.status_code,
                    "response": e.response.text
                })
                return None
            except Exception as e:
                logger.error("Apple Music search failed", extra={"error": str(e)})
                return None
    
    async def search_by_metadata(
        self,
        artist: str,
        title: str,
        storefront: str = "us",
        limit: int = 5
    ) -> list[dict]:
        """
        Search Apple Music catalog by artist and title (fuzzy search).
        
        Args:
            artist: Artist name
            title: Track title
            storefront: Apple Music storefront/region
            limit: Maximum results to return
            
        Returns:
            List of song data dicts
        """
        token = self.get_token()
        url = f"{self.BASE_URL}/catalog/{storefront}/search"
        
        headers = {
            "Authorization": f"Bearer {token}"
        }
        
        # Construct search query
        query = f"{artist} {title}"
        
        params = {
            "term": query,
            "types": "songs",
            "limit": limit
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers, params=params, timeout=10.0)
                response.raise_for_status()
                
                data = response.json()
                results = data.get("results", {}).get("songs", {}).get("data", [])
                
                logger.info("Apple Music metadata search complete", extra={
                    "query": query,
                    "results_count": len(results)
                })
                
                return results
                
            except httpx.HTTPStatusError as e:
                logger.error("Apple Music API error", extra={
                    "status": e.response.status_code,
                    "response": e.response.text
                })
                return []
            except Exception as e:
                logger.error("Apple Music search failed", extra={"error": str(e)})
                return []


@lru_cache()
def get_apple_music_service() -> AppleMusicService:
    """Get cached Apple Music service instance"""
    return AppleMusicService()
