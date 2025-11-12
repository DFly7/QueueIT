## QueueUp Repository Code Review (Backend + iOS)

### Executive Summary

Solid foundations with a clean FastAPI setup, typed responses, and a working Spotify search flow. Auth via Supabase JWKS is correctly designed. iOS search UI is working and clean. Major MVP features (sessions, queue, voting, real-time, auth in app) are scaffolded but not implemented. Focus next on completing core endpoints, adding WebSockets, and integrating iOS auth + session flows. Minor dependency hygiene and missing operational artifacts (ENV.example, tests, deployment) should be addressed.

---

### Backend (FastAPI + Supabase)

- Architecture
  - Organized modules: `api/v1`, `core`, `schemas`, `services`. Good separation of concerns.
  - Typed Pydantic response models for Spotify search results ensure predictable API shape.
  - Custom OpenAPI schema adds BearerAuth globally to `/api/v1/*`, great for DX.
- Auth/Security
  - JWKS-based JWT verification against Supabase is correctly implemented with caching (`JWKSManager`). Supports RSA/EC. Good error handling granularity.
  - Note: `verify_jwt` is not currently enforced on the router (commented dependency). This should be enabled for protected endpoints.
- Configuration
  - `Settings` and `get_settings()` pattern is correct. Loads env via `python-dotenv`.
  - `ALLOWED_ORIGINS` handling is flexible. Default `*` is fine for dev; tighten in prod.
- Spotify Service
  - Token caching in-memory is fine for single-process dev. Production may need process-safe cache (Redis) if scaled horizontally.
  - Timeouts included; errors surfaced cleanly as `ValueError` for auth issues.
- Schemas
  - `TrackOut` model uses aliases (e.g., `spotify_id`, `durationMSs`), but `populate_by_name = True` allows using intuitive names as supplied from parser. Consider removing non-standard aliases to avoid confusion.
  - `Session` and `QueuedSongResponse` models are well-thought “view models”. Good separation from DB layer.
- API Modules
  - `spotify.py`: robust endpoint, parses Spotify’s complex JSON to a clean `TrackOut` list.
  - `sessions.py` and `songs.py`: endpoints are largely stubs with correct signatures and comments. The intent is clear; implementation is pending.
- Error Handling & Logging
  - Uses `HTTPException` appropriately in `spotify.py`. Elsewhere, `print()` is used—replace with structured logging (e.g., `logging`).
- Dependencies
  - `requirements.txt` contains both `dotenv` and `python-dotenv`. Remove `dotenv` to avoid confusion; `python-dotenv` is the correct package already included.
- Documentation/Examples
  - Backend README is helpful but references `ENV.example` which is missing. Add an example env file.
- Testing
  - No tests yet; `tests/test.py` is empty. Add minimal endpoint tests and one WebSocket test.

Priority Recommendations (Backend)

1. Enforce `verify_jwt` on `/api/v1` routes (or per-router).
2. Implement sessions and queue/vote endpoints with deterministic ordering.
3. Add WebSocket broadcasting for session updates.
4. Provide `ENV.example` and remove `dotenv` from requirements.
5. Add basic tests and structured logging.
6. Document Supabase schema and RLS policies; commit SQL to repo.

---

### iOS (SwiftUI)

- Architecture & State
  - `TrackSearchViewModel` is clean, uses Combine for debounced search and async calls for execution. Good separation of concerns.
  - `ContentView` presents search and results in a straightforward way with `AsyncImage`.
- Networking & Errors
  - Base URL is hard-coded. Introduce configuration for dev/prod (e.g., build settings or plist).
  - Error surfaces raw server response; consider user-friendly mapping and optional Sentry for crash reporting later.
- Auth
  - No auth; add Supabase Swift (email login) to obtain JWT for protected endpoints.
- Features
  - No session UI: create/join with code/QR, queue display, voting, skip, now playing.
  - No WebSocket handling; add a lightweight WS client for `queue.updated`/`votes.updated` events.
- Data Models
  - `Track` matches backend response; good.
  - Add models for `Session`, `QueuedSong`, `CurrentSessionResponse` aligned with backend schemas.
- UX/Polish
  - Good start. Add empty states and haptics for vote/add; show active vote state; add “Skip” vote banner when threshold nears.
- Testing
  - None yet. Add a couple of unit tests for ViewModel parsing and an integration test for the search flow.

Priority Recommendations (iOS)

1. Add Supabase Swift auth (email OTP/magic link).
2. Implement Create/Join Session flows, including QR presentation/scanning.
3. Build Queue screen with voting, now playing, and optimistic updates.
4. Integrate WebSockets for live updates.
5. Add environment config and basic analytics/crash reporting later.

---

### DevOps / Tooling

- Deployment
  - Add Fly.io or Render config (Dockerfile or native). Set env vars and CORS.
  - Health endpoint exists; leverage for uptime checks.
- CI/CD
  - Add GitHub Actions for lint/test on PR and deploy on main.
- Observability
  - Add structured logging (backend) and consider simple request logging middleware.
- Security
  - Keep secrets in env only. Consider PostHog or Sentry later (not MVP-critical).
- Repo Hygiene
  - Add `ENV.example` showing `SPOTIFY_*`, `SUPABASE_*`, `ALLOWED_ORIGINS`.
  - Consider `supabase/` folder with schema and RLS SQL.

---

### Suggested Supabase Schema (Outline)

- tables
  - `sessions`: id (uuid pk), join_code (text unique), host_id (uuid), is_locked (bool), created_at (timestamptz)
  - `session_members`: id (uuid pk), session_id (fk), user_id (uuid), joined_at (timestamptz)
  - `queued_songs`: id (uuid pk), session_id (fk), added_by (uuid), spotify_id (text), title (text), artists (text), album (text), image_url (text), duration_ms (int), status (text: queued|playing|played), added_at (timestamptz)
  - `votes`: id (uuid pk), queued_song_id (fk), user_id (uuid), value (int: -1|1), created_at (timestamptz), unique (queued_song_id, user_id)
- RLS (indicative)
  - Members can select rows in their session; insert queued songs in current session; upsert votes where user_id = auth.uid(); host can control session flags.

---

### API Contracts (MVP Summary)

- Sessions
  - POST `/api/v1/sessions/create` { join_code } → { session }
  - POST `/api/v1/sessions/join` { join_code } → { session }
  - GET `/api/v1/sessions/current` → { session, current_song, queue[] }
  - POST `/api/v1/sessions/leave` → { ok: true }
  - PATCH `/api/v1/sessions/control_session` { is_locked?, skip_current_track?, pause_playback? } → { ok: true }
- Queue/Votes
  - POST `/api/v1/songs/add` { spotify_id, name, artists, album, duration_ms, image_url } → { queued_song }
  - POST `/api/v1/songs/{id}/vote` { value: 1|-1 } → { votes, queued_song }
- Search
  - GET `/api/v1/spotify/search?q=...&limit=...` → { tracks: TrackOut[] }
- Realtime
  - WS `/api/v1/sessions/{id}/realtime` → events: `queue.updated`, `votes.updated`, `now_playing.updated`

---

### Quick Wins

- Enforce JWT on routes; add `ENV.example`; remove `dotenv` from requirements.
- Add minimal endpoint tests and one WS broadcast test.
- Add iOS environment config and stub session screens.
