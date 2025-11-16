## QueueUp Repository Code Review — 2025-11-16

### Executive Summary
Substantial progress since the previous review. Auth is now enforced globally for `/api/v1/*`. Sessions and songs APIs are implemented via clean service + repository layers. Queue aggregation (votes, user, song join) and deterministic ordering are in place. Track schemas are updated and request models for adding songs are defined. Remaining work centers on real-time updates (WebSockets), session control completeness (skip threshold, lock), tests, and a few dependency/config hardenings.

---

### What Improved
- Auth enforcement: `api/v1/router.py` now uses `Depends(verify_jwt)` globally.
- Layered design: Introduced `repositories/` and `services/` with clear boundaries.
  - `QueueRepository`: add/list queue, vote upsert with total aggregation, batch fetch maps.
  - `SongRepository`: upsert and fetch songs.
  - `session_service.py`: create/join/current/leave/control flows wired through repositories.
  - `queue_service.py`: add to queue and vote, returning typed view models.
- Contracts: `AddSongRequest` defined; `QueuedSongResponse` mapping implemented.
- Sessions API: implemented CRUD-like operations and `CurrentSessionResponse` composition.

---

### Current Risks and Gaps
- Real-time updates: No WebSocket events yet for queue/votes/now playing.
- Playback/skip logic:
  - No 50%+ skip voting mechanic; `control_session` only clears `current_song` when `skip_current_track` is set by host.
  - No automatic “advance queue” or scheduled updates.
- Security/Compliance:
  - JWKS manager created at import time; consider lazy init or startup handler + TTL refresh.
  - CORS wildcard with credentials remains a pitfall for browsers; use explicit allowed origins in prod.
- Dependencies:
  - `PyJWT` still missing in `requirements.txt` though used by `app/core/auth.py`.
  - Consider retry/backoff for Spotify rate limits and network flakiness.
- Testing:
  - No automated tests for repos/services/endpoints; notebook exists but not CI-friendly.

---

### Detailed Notes
- API Routers
  - `app/api/v1/router.py`: Good composition and global auth dependency. Includes `spotify`, `sessions`, and `songs` routers. Provides simple `/ping` and `/secure-test`.
  - `sessions.py`: Endpoints return `CurrentSessionResponse` with correct mapping. Host control currently supports skip clearing only.
  - `songs.py`: Adds song with `AddSongRequest`, returns `QueuedSongResponse`. Vote endpoint updates total and returns it.
- Services
  - `session_service.py`: Composes `SessionBase`, `QueuedSongResponse`, and handles membership via `users.current_session`. Good shape for extension (lock/permissions/skip-vote).
  - `queue_service.py`: Ensures the song row exists before queueing; reuses list aggregation to return the enriched object. Nice reuse.
- Repositories
  - `QueueRepository.list_session_queue` fetches rows, batches related entities, calculates total votes, and sorts by votes desc, created_at asc—matches product requirements.
  - `vote_on_song` uses `upsert` with on_conflict; correct for changing votes. Aggregates totals.
  - `SongRepository.upsert_song` ids on `spotify_id`. Aligns with schema.
- Schemas
  - `TrackOut` and `AddSongRequest` use `Annotated` + aliasing; good for API ergonomics. The parse logic should continue to supply safe defaults when Spotify fields are missing.

---

### High-Impact Next Steps
1. Real-time
   - Add WebSocket endpoint: `/api/v1/sessions/{id}/realtime` broadcasting events:
     - `queue.updated`, `votes.updated`, `now_playing.updated`.
   - Trigger broadcasts after `/songs/add`, `/songs/{id}/vote`, and session control changes.
2. Skip vote threshold
   - Track per-session active members; when votes to skip current song exceed 50% of active participants, clear `current_song` and advance queue.
3. Tests
   - Unit: repositories (vote upsert, aggregation sorting), services (create/join/current), auth (JWKS, iss/aud).
   - Integration: `/songs/add`, `/songs/{id}/vote`, `/sessions/current` happy paths and RLS enforcement.
   - Optional: WebSocket broadcast smoke test.
4. Dependencies & Config
   - Add `PyJWT>=2.8` to `requirements.txt`.
   - Consider retry/backoff for Spotify (429/5xx) and lock token refresh.
   - Tighten CORS for prod (explicit origins when `allow_credentials=True`).
5. Operational Docs
   - Document Supabase schema application and RLS expectations (supabase folder already present).
   - Add endpoint examples to API_CONTRACTS.md (see new doc).

---

### Suggested Enhancements (Nice-to-have)
- Structured logging; map exceptions to a consistent error response shape.
- Request correlation IDs.
- Basic rate limiting for public endpoints.
- CI with GitHub Actions to run tests/linters.

---

### iOS Impact
- With sessions/queue/vote endpoints available, wire:
  - Auth (Supabase Swift) to pass JWT in requests.
  - Session create/join/current UI.
  - Add track from search → call `/songs/add`.
  - Vote buttons calling `/songs/{id}/vote`.
  - WebSocket client to reflect real-time changes immediately.


