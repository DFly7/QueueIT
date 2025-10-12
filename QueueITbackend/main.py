import requests
import json
import os
from dotenv import load_dotenv
import base64

load_dotenv()




def get_spotify_data():


        # Encode client credentials
    auth_str = f"{os.getenv("CLIENT_ID")}:{os.getenv("CLIENT_SECRET")}"
    b64_auth_str = base64.b64encode(auth_str.encode()).decode()

    # Request token
    response = requests.post(
        "https://accounts.spotify.com/api/token",
        headers={"Authorization": f"Basic {b64_auth_str}"},
        data={"grant_type": "client_credentials"},
    )

    ACCESS_TOKEN = response.json()["access_token"]
    print("Access Token:", ACCESS_TOKEN)

    
    url = "https://api.spotify.com/v1/search"


    params = {
        "q": "radiohead",
        "type": "track",
        "limit": 1
    }

    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}"
    }

    # Send GET request
    response = requests.get(url, headers=headers, params=params)

    # Check if request was successful
    if response.status_code == 200:
        data = response.json()
        exclude_keys = {"available_markets", "href"}
        def clean_dict(d):
            """Recursively remove excluded keys from nested dicts/lists."""
            if isinstance(d, dict):
                return {
                    k: clean_dict(v)
                    for k, v in d.items()
                    if k not in exclude_keys
                }
            elif isinstance(d, list):
                return [clean_dict(i) for i in d]
            else:
                return d
        cleaned_data = clean_dict(data)

        # Pretty print the result
        print(json.dumps(cleaned_data, indent=2))
        return cleaned_data
    else:
        print(f"Error: {response.status_code}")
        print(response.text)

get_spotify_data()