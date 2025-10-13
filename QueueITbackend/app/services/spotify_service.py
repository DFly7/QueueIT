import base64
import os
from typing import Any, Dict

import requests

from app.core.config import get_settings


def _get_access_token() -> str:
    settings = get_settings()
    client_id = settings.client_id or os.getenv("CLIENT_ID")
    client_secret = settings.client_secret or os.getenv("CLIENT_SECRET")
    if not client_id or not client_secret:
        raise ValueError("Missing CLIENT_ID or CLIENT_SECRET")

    auth_str = f"{client_id}:{client_secret}"
    b64_auth_str = base64.b64encode(auth_str.encode()).decode()

    response = requests.post(
        "https://accounts.spotify.com/api/token",
        headers={"Authorization": f"Basic {b64_auth_str}"},
        data={"grant_type": "client_credentials"},
        timeout=20,
    )
    response.raise_for_status()
    return response.json()["access_token"]


def search_spotify(query: str, search_type: str = "track", limit: int = 5) -> Dict[str, Any]:
    token = _get_access_token()
    url = "https://api.spotify.com/v1/search"
    params = {"q": query, "type": search_type, "limit": limit}
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers, params=params, timeout=20)
    response.raise_for_status()
    data = response.json()

    exclude_keys = {"available_markets", "href"}

    def clean_dict(d):
        if isinstance(d, dict):
            return {k: clean_dict(v) for k, v in d.items() if k not in exclude_keys}
        if isinstance(d, list):
            return [clean_dict(i) for i in d]
        return d

    return clean_dict(data)


