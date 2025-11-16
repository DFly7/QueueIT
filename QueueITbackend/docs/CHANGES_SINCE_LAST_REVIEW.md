## Changes Since Last Review

### Added
- Global auth enforcement on all `/api/v1/*` routes via `api/v1/router.py`.
- Repository layer:
  - `QueueRepository`: add to queue, fetch enriched queue, vote upsert + totals.
  - `SongRepository`: upsert/fetch catalog songs.
- Service layer:
  - `session_service.py`: create/join/current/leave/control session flows.
  - `queue_service.py`: add song to queue and vote-for-song orchestration.
- API contracts:
  - `AddSongRequest` and `QueuedSongResponse` implemented and returned from endpoints.
  - `sessions.py` endpoints now return `CurrentSessionResponse`.
- Documentation:
  - `ARCHITECTURE.md` (new)
  - `API_CONTRACTS.md` (new)
  - `REPO_CODE_REVIEW_2025-11-16.md` (new)

### Changed
- `TrackOut` schema now uses `Annotated` with aliases (e.g., `id` alias for `spotify_id`).
- `songs.py` now handles add and vote endpoints and delegates to services.
- `sessions.py` now delegates to services for all essential flows.

### Pending / Next
- Realtime WebSockets for `queue.updated`, `votes.updated`, `now_playing.updated`.
- Skip voting threshold and automatic queue advance.
- Tests for repositories, services, endpoints, and auth.
- Add `PyJWT` to `requirements.txt` and tighten CORS for production.


