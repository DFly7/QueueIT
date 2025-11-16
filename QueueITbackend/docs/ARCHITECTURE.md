## QueueUp Architecture Overview

### High-Level
- iOS app (SwiftUI) calls the FastAPI backend for search, sessions, queue and voting.
- Backend authenticates requests via Supabase JWT (JWKS). Data is stored in Supabase Postgres with RLS.
- Planned WebSocket channel broadcasts queue/vote/now-playing updates to clients.

### Backend Layers
- API Routers (`app/api/v1/`)
  - `router.py`: Aggregates routers and enforces auth for all `/api/v1/*`.
  - `spotify.py`: Search endpoint returning `TrackOut[]`.
  - `sessions.py`: Session lifecycle (`create`, `join`, `current`, `leave`, `control_session`).
  - `songs.py`: Queue operations (`add`, `vote`).
- Services (`app/services/`)
  - `session_service.py`: Orchestrates session flows and shapes responses (`CurrentSessionResponse`).
  - `queue_service.py`: Ensures catalog song, adds to queue, handles votes, and maps to `QueuedSongResponse`.
  - `spotify_service.py`: Client Credentials flow + search proxy to Spotify.
- Repositories (`app/repositories/`)
  - `QueueRepository`: Add/list queue, vote upsert, vote totals, join song/user details, sort.
  - `SongRepository`: Upsert/fetch songs in the catalog.
  - (Plus `SessionRepository`, `UserRepository` referenced by services.)
- Core (`app/core/`)
  - `auth.py`: Supabase JWT verification (JWKS), FastAPI dependencies providing user-authenticated Supabase client.
  - `config.py`: Settings and env management.

### Data Model (Supabase)
- `users`: user profile row keyed by Supabase `auth.users.id`; `current_session` tracks active session.
- `sessions`: host-managed room with `join_code` and optional `current_song`.
- `songs`: catalog keyed by `spotify_id` (upserted on demand).
- `queued_songs`: per-session queue with `status` and timestamps.
- `votes`: per-queued-song votes with one-per-user constraint (upsert).
- RLS: Access constrained by user id and session membership (see `supabase/rls_policies.sql` scaffolding).

### Request Flow Example: Add Song
1. iOS sends POST `/api/v1/songs/add` with `AddSongRequest`.
2. Auth dependency verifies JWT and provides a RLS-enabled Supabase client.
3. Service ensures song exists (upsert), adds queued song, then reuses aggregated list to shape `QueuedSongResponse`.
4. Future: emit `queue.updated` over WS channel for the session.

### Real-time Plan
- WS: `/api/v1/sessions/{id}/realtime` broadcasting:
  - `queue.updated` (on add/vote), `now_playing.updated` (on control), `session.updated` (host flags).
- iOS listens and updates UI immediately; fall back to GET `/sessions/current` on reconnect.

### Configuration
- Env vars in `QueueITbackend/ENV.example`: `ENVIRONMENT`, `ALLOWED_ORIGINS`, `SPOTIFY_CLIENT_ID/SECRET`, `SUPABASE_URL/PUBLIC_ANON_KEY`.
- CORS: Wildcard for dev; explicit allowlist for production if `allow_credentials=True`.

### Testing Strategy
- Unit: repositories (aggregation and sorting), services (flows), auth (JWKS/aud/iss).
- Integration: endpoints (`/sessions/*`, `/songs/*`, `/spotify/search`).
- Realtime: basic WS connect/broadcast test.


