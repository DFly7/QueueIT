# Database Transaction Audit

**Last updated:** 2026-03-15

This document catalogs all database calls in the QueueIT backend and identifies which flows need transactional behavior for data consistency.

## Context

- **Stack:** Supabase (PostgreSQL via REST API), Python SDK
- **Limitation:** The Supabase Python SDK does **not** expose transactions. Each `.execute()` is a separate HTTP request; commits are implicit per request.
- **Mitigation:** PostgreSQL RPC functions (called via `client.rpc()`) run in a single DB transaction. Use RPCs for multi-step writes that must be atomic.

---

## Flows That NEED Transactions

### 1. Create Session (`create_session_for_user`)

**Location:** [QueueITbackend/app/services/session_service.py](QueueITbackend/app/services/session_service.py) lines 121-174

**Call sequence:**
1. `session_repo.create_session(...)` — INSERT sessions
2. `user_repo.set_current_session(...)` — UPDATE users.current_session

**Risk:** If step 2 fails, orphaned session exists (session row with no user linked as host/participant).

**Fix:** Add PostgreSQL RPC `create_session_and_join(p_host_id, p_join_code, p_host_provider)` that:
- INSERTs into `sessions`
- UPDATEs `users.current_session`
- Returns session details as JSON

---

### 2. Add Song to Queue (`add_song_to_queue_for_user`)

**Location:** [QueueITbackend/app/services/queue_service.py](QueueITbackend/app/services/queue_service.py) lines 44-176

**Call sequence:**
1. `song_repo.upsert_song(...)` — UPSERT songs
2. `queue_repo.add_song_to_queue(...)` — INSERT queued_songs
3. `session_repo.set_current_song_if_empty(...)` — UPDATE sessions.current_song (conditional)
4. `queue_repo.update_song_status(...)` — UPDATE queued_songs.status (if step 3 succeeded)

**Risk:** Partial state if any write fails after the first:
- Song exists but not in queue
- Song in queue but not set as current when queue was empty
- Current song set but status not "playing"

**Fix:** Add PostgreSQL RPC `add_song_to_queue_atomic(...)` that:
- UPSERTs into `songs`
- INSERTs into `queued_songs`
- Conditionally UPDATEs `sessions.current_song` (WHERE current_song IS NULL)
- If that update matched, UPDATEs the new queued_song status to `playing`
- Returns the new queued_song row

---

### 3. Host Skip / Advance to Next Song (`control_session_for_user` + `_advance_to_next_song`)

**Location:** [QueueITbackend/app/services/session_service.py](QueueITbackend/app/services/session_service.py) lines 241-308

**Call sequence (host skip or song_finished):**
1. `queue_repo.update_song_status(current_song_id, "skipped"|"played")` — UPDATE queued_songs
2. `skip_repo.clear_skip_requests(session_id)` — DELETE from skip_requests
3. `queue_repo.get_next_queued_song(session_id)` — SELECT
4. `queue_repo.update_song_status(next_song_id, "playing")` — UPDATE queued_songs
5. `session_repo.set_current_song(...)` — UPDATE sessions.current_song

**Risk:** Inconsistent state if a write fails mid-flow:
- Current song marked skipped/played but next song not advanced
- Skip requests cleared but current song not updated
- Session pointing to wrong/null current_song

**Fix:** Add PostgreSQL RPC `host_advance_to_next_song(p_session_id)` that:
- Marks current queued_song as skipped/played (depending on caller intent, or parameter)
- Clears skip_requests
- Finds next queued song (ORDER BY votes, etc.)
- Updates its status to `playing`
- Updates sessions.current_song to new id or NULL
- Returns next song id or NULL

`control_session_for_user` (skip) and `song_finished_for_user` (played) would both call this RPC.

---

### 4. Song Finished (`song_finished_for_user`)

**Location:** [QueueITbackend/app/services/session_service.py](QueueITbackend/app/services/session_service.py) lines 357-403

**Call sequence:**
- Same as host skip: `queue_repo.update_song_status("played")` then `_advance_to_next_song(...)`.

**Fix:** Same RPC as #3 (`host_advance_to_next_song`) with a parameter to distinguish "played" vs "skipped" for the current song status.

---

## Flows That Are Already OK (Single Write or Atomic RPC)

| Flow | Location | Why OK |
|------|----------|--------|
| Join session | `session_service.join_session_by_code` | Single write: `user_repo.set_current_session` |
| Leave session | `session_service.leave_current_session_for_user` | Single write: `user_repo.set_current_session(None)` |
| Vote on song | `queue_service.vote_for_queued_song` | Single upsert: `queue_repo.vote_on_song` |
| Remove vote | `queue_service.remove_vote_from_queued_song` | Single delete: `queue_repo.remove_vote` |
| Request skip | `session_service.request_skip_for_user` | Single write + optional RPC. `crowdsourced_skip_advance` is already a transactional RPC |
| Update profile | `users.update_current_user_profile` | Single write: `user_repo.update_profile`. Username check is read-then-write but unique constraint catches races |

---

## Individual Repo Methods (Reference)

### SessionRepository
- `create_session` — INSERT
- `get_by_join_code`, `get_by_id`, `get_current_for_user` — SELECT
- `set_current_song`, `set_current_song_if_empty` — UPDATE (atomic conditional)

### UserRepository
- `get_by_id` — SELECT
- `update_profile`, `set_current_session` — UPDATE

### QueueRepository
- `add_song_to_queue` — INSERT
- `get_queued_song`, `get_next_queued_song`, `list_session_queue`, `get_user_votes_for_session` — SELECT
- `update_song_status` — UPDATE
- `vote_on_song` — UPSERT (atomic)
- `remove_vote` — DELETE

### SongRepository
- `get_by_external_id` — SELECT
- `upsert_song` — UPSERT

### SkipRequestRepository
- `insert_request` — UPSERT
- `clear_skip_requests` — RPC (single atomic DELETE)
- `crowdsourced_skip_advance` — RPC (atomic: mark skipped, clear requests, advance)
- `get_skip_request_count`, `get_participant_count`, `user_has_requested_skip` — RPCs (read-only)

---

## Implementation Priority

1. **High:** `create_session_for_user` — orphaned sessions are user-visible and confusing
2. **High:** `host_advance_to_next_song` (for skip + song_finished) — queue state corruption affects playback
3. **Medium:** `add_song_to_queue_atomic` — failures are rarer; partial state less severe

---

## Existing RPCs (Already Transactional)

- `crowdsourced_skip_advance` — used when 50%+ participants request skip; performs full advance atomically
- `clear_skip_requests`, `get_session_skip_request_count`, `get_session_participant_count`, `user_has_skip_request` — read/delete helpers
- `get_user_votes_for_session` — read-only
