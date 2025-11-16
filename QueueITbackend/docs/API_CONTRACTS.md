## API Contracts (MVP)

All endpoints under `/api/v1/*` require a Bearer JWT from Supabase. Include header:
`Authorization: Bearer <token>`

### Spotify
- GET `/api/v1/spotify/search?q=<query>&limit=<1..50>`
  - Response:
    - `200 OK`:
      - `{ "tracks": TrackOut[] }`
    - TrackOut:
      - `id` (alias for `spotify_id`), `isrc`, `name`, `artists`, `album`, `duration_ms`, `image_url`

### Sessions
- POST `/api/v1/sessions/create`
  - Body: `SessionCreateRequest`
    - `join_code: string (4..20)`
  - Response: `CurrentSessionResponse`
- POST `/api/v1/sessions/join`
  - Body: `SessionJoinRequest`
    - `join_code: string (4..20)`
  - Response: `CurrentSessionResponse`
- GET `/api/v1/sessions/current`
  - Response: `CurrentSessionResponse`
- POST `/api/v1/sessions/leave`
  - Response: `{ "ok": true }`
- PATCH `/api/v1/sessions/control_session`
  - Body: `SessionControlRequest`
    - `is_locked?: boolean`
    - `skip_current_track?: boolean`
    - `pause_playback?: boolean`
  - Response: `{ "ok": true }`

Models:
- `CurrentSessionResponse`:
  - `session: SessionBase`
  - `current_song?: QueuedSongResponse`
  - `queue: QueuedSongResponse[]`
- `SessionBase`:
  - `id: uuid`, `join_code: string`, `created_at: timestamp`, `host: User`
- `QueuedSongResponse`:
  - `id: uuid`, `status: string`, `added_at: timestamp`, `votes: number`, `song: TrackOut`, `added_by: User`
- `User`:
  - `id: uuid`, `username?: string`
- `TrackOut`:
  - `id (spotify_id): string`, `isrc: string`, `name: string`, `artists (artist): string`, `album: string`, `duration_ms (durationMSs): number`, `image_url?: string`

### Queue / Songs
- POST `/api/v1/songs/add`
  - Body: `AddSongRequest`
    - `id (spotify_id): string`
    - `isrc (isrc_identifier): string`
    - `name: string`
    - `artists (artist): string`
    - `album: string`
    - `duration_ms (durationMSs): number`
    - `image_url: string`
  - Response: `QueuedSongResponse`
- POST `/api/v1/songs/{queued_song_id}/vote`
  - Body: `VoteRequest`
    - `vote_value: 1 | -1`
  - Response:
    - `{ "ok": true, "total_votes": number }`

### Realtime (planned)
- WS `/api/v1/sessions/{id}/realtime`
  - Events:
    - `queue.updated` → `{ session_id, queue: QueuedSongResponse[] }`
    - `votes.updated` → `{ session_id, queued_song_id, total_votes }`
    - `now_playing.updated` → `{ session_id, current_song?: QueuedSongResponse }`


