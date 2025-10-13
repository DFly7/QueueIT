import base64
import os
import time
from typing import Any, Dict, Optional

import requests
from app.core.config import get_settings

# --- Simple in-memory cache for the token ---
_cached_token: Optional[Dict[str, Any]] = None

def _get_access_token() -> str:
    global _cached_token
    
    # If token exists and is not expired, return it
    if _cached_token and _cached_token["expires_at"] > time.time():
        return _cached_token["access_token"]

    # --- Otherwise, fetch a new one ---
    settings = get_settings()
    client_id = settings.client_id or os.getenv("CLIENT_ID")
    client_secret = settings.client_secret or os.getenv("CLIENT_SECRET")
    if not client_id or not client_secret:
        raise ValueError("Missing CLIENT_ID or CLIENT_SECRET environment variables")

    auth_str = f"{client_id}:{client_secret}"
    b64_auth_str = base64.b64encode(auth_str.encode()).decode()

    # <-- CHANGED: Using the real Spotify Accounts URL
    response = requests.post(
        "https://accounts.spotify.com/api/token",
        headers={"Authorization": f"Basic {b64_auth_str}"},
        data={"grant_type": "client_credentials"},
        timeout=10,
    )
    response.raise_for_status()
    token_data = response.json()

    # Cache the new token with its expiration time
    _cached_token = {
        "access_token": token_data["access_token"],
        "expires_at": time.time() + token_data["expires_in"] - 60  # -60s for safety margin
    }
    
    return _cached_token["access_token"]

def search_spotify(query: str, search_type: str = "track", limit: int = 5) -> Dict[str, Any]:
    try:
        token = _get_access_token()
    except Exception as e:
        # If token fetching fails, it's a server-side configuration issue
        raise ValueError(f"Could not authenticate with Spotify: {e}")

    # <-- CHANGED: Using the real Spotify Search API URL
    api_url = "https://api.spotify.com/v1/search"
    params = {"q": query, "type": search_type, "limit": limit}
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(api_url, headers=headers, params=params, timeout=10)
    response.raise_for_status()
    
    # <-- REMOVED: No need for clean_dict. Return the raw data.
    # The Pydantic response_model will handle filtering.
    return response.json()