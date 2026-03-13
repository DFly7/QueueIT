# Todo

## Apple Music API 429 Rate Limiting

**Problem:** When users add Spotify songs to a session with an Apple Music host, the backend resolves tracks to Apple Music and fetches metadata. Rapid or concurrent adds trigger `429 Too Many Requests` from the Apple Music API, causing "Failed to fetch Apple Music track data" errors.

**Error example:**
```
Client error '429 Too Many Requests' for url 'https://api.music.apple.com/v1/catalog/gb/songs/{apple_id}'
```

**Planned fix:** Add retry logic with exponential backoff to `extract_apple_music_track_data` in `QueueITbackend/app/services/song_matching_service.py`:

- On 429 response: retry up to 3 times with exponential backoff (e.g. 2s, 4s, 8s)
- Only retry on 429, not other HTTP errors
- Log retry attempts

**Future improvement:** Cache Apple Music track data by `apple_id` in the database or Redis so repeated adds of the same song skip the API call.
