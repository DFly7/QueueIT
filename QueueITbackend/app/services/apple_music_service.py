"""
Apple Music API Service

Handles Apple Music Developer Token generation and API calls.
Uses private key to generate JWT for server-to-server authentication.
"""

import time
import jwt
import httpx
from functools import lru_cache
from pathlib import Path
from typing import Optional

from app.core.config import get_settings
from app.logging_config import get_logger

logger = get_logger(__name__)


class AppleMusicService:
    """Service for Apple Music API operations"""
    
    BASE_URL = "https://api.music.apple.com/v1"
    TOKEN_EXPIRY = 15777000  # 6 months in seconds (Apple's max)
    
    def __init__(self):
        self.settings = get_settings()
        self._token: Optional[str] = None
        self._token_expires_at: float = 0
        
    def _load_private_key(self) -> str:
        """Load Apple Music private key from file"""
        if not self.settings.apple_private_key_path:
            raise ValueError("APPLE_PRIVATE_KEY_PATH not configured")
            
        key_path = Path(self.settings.apple_private_key_path)
        if not key_path.is_absolute():
            # Relative to backend root
            key_path = Path(__file__).parent.parent.parent / key_path
            
        if not key_path.exists():
            raise FileNotFoundError(f"Apple Music private key not found: {key_path}")
            
        with open(key_path, 'r') as f:
            return f.read()
    
    def _generate_token(self) -> str:
        """Generate Apple Music Developer Token (JWT)"""
        if not all([
            self.settings.apple_team_id,
            self.settings.apple_key_id,
            self.settings.apple_private_key_path
        ]):
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
        preferred_album: Optional[str] = None
    ) -> Optional[dict]:
        """
        Search Apple Music catalog by ISRC.
        
        Args:
            isrc: International Standard Recording Code
            storefront: Apple Music storefront/region (e.g., 'us', 'gb', 'ca')
            preferred_album: Optional album name to prefer when multiple versions exist
            
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
                
                # Log when multiple versions exist
                if len(results) > 1:
                    logger.info("Multiple Apple Music versions found for ISRC", extra={
                        "isrc": isrc,
                        "count": len(results),
                        "albums": [r.get("attributes", {}).get("albumName") for r in results]
                    })
                
                # If preferred album specified, try to match it
                if preferred_album and len(results) > 1:
                    preferred_album_lower = preferred_album.lower()
                    for result in results:
                        apple_album = result.get("attributes", {}).get("albumName", "")
                        if apple_album.lower() == preferred_album_lower:
                            logger.info("Found Apple Music track with matching album", extra={
                                "isrc": isrc,
                                "apple_id": result["id"],
                                "name": result["attributes"].get("name"),
                                "album": apple_album,
                                "preferred": True
                            })
                            return result
                
                # Default: Take first match
                song = results[0]
                logger.info("Found Apple Music track by ISRC", extra={
                    "isrc": isrc,
                    "apple_id": song["id"],
                    "name": song["attributes"].get("name"),
                    "album": song["attributes"].get("albumName"),
                    "preferred": False
                })
                return song
                    
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
