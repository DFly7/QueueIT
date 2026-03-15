# Crowdsourced Skip — Implementation Notes

Implemented from [`crowdsourced_skip_button.plan.md`](./crowdsourced_skip_button.plan.md).

---

## What was built

Any session participant can tap "Request to Skip" on the Now Playing card. When more than 50% of participants have requested a skip the backend advances the song automatically (same outcome as a host skip) and clears all requests. The host retains their existing one-tap skip in Host Controls.

---

## Database

### New table: `skip_requests`

```sql
(session_id UUID, user_id UUID, PRIMARY KEY (session_id, user_id))
```

Composite primary key ensures one request per user per song cycle. Rows are cleared on every song advance (host skip, `song_finished`, or crowdsourced skip).

### Migrations

| File | Purpose |
|------|---------|
| `20260317_skip_requests.sql` | Table, RLS policies, and read-only RPCs |
| `20260317_skip_requests_realtime.sql` | Adds table to `supabase_realtime` publication |
| `20260317_crowdsourced_skip_rpc.sql` | Full advance RPC (see below) |

### SECURITY DEFINER RPCs

Regular participants cannot `UPDATE queued_songs` or `UPDATE sessions` via RLS (those policies are host-only). All write operations during a crowdsourced skip go through SECURITY DEFINER functions that bypass RLS:

| RPC | Purpose |
|-----|---------|
| `get_session_participant_count(p_session_id)` | Count users with `current_session = session_id` |
| `get_session_skip_request_count(p_session_id)` | Count active skip requests |
| `user_has_skip_request(p_session_id, p_user_id)` | Check if a user already requested |
| `clear_skip_requests(p_session_id)` | DELETE all requests (called on host/natural advance) |
| `crowdsourced_skip_advance(p_session_id)` | Full atomic advance — see below |

#### `crowdsourced_skip_advance`

Single atomic function called when threshold is met. Performs in one transaction:

1. Mark `current_song` as `skipped`
2. DELETE all `skip_requests` for the session
3. Find next queued song (same tier-sort as Python: votes DESC → `entered_tier_by_gain` ASC → `last_entered_tier_at` → `created_at`)
4. Mark next song as `playing`
5. Set `sessions.current_song` to the next song (or NULL if queue empty)
6. Returns the new `queued_song` UUID

> **Why an RPC instead of widened RLS?** `sessions_update_host` is intentionally host-only — opening it to all members would let any participant update `host_id`, `join_code`, or `host_provider`. The RPC is scoped to exactly the fields it needs.

---

## Backend

### New files

- `app/repositories/skip_request_repo.py` — `SkipRequestRepository`
- Updated `app/repositories/__init__.py` to export it

### `SkipRequestRepository` methods

| Method | Description |
|--------|-------------|
| `insert_request(session_id, user_id)` | Upsert skip request (idempotent) |
| `get_skip_request_count(session_id)` | Via RPC |
| `get_participant_count(session_id)` | Via RPC |
| `user_has_requested_skip(session_id, user_id)` | Via RPC |
| `clear_skip_requests(session_id)` | Via RPC — called on host/natural advances |
| `crowdsourced_skip_advance(session_id)` | Via RPC — called when threshold met |

### Updated service: `session_service.py`

**`request_skip_for_user`** (new function):
1. Upserts skip request
2. Fetches counts
3. If `skip_request_count > participant_count / 2` → calls `crowdsourced_skip_advance` RPC and returns `skipped: true`
4. Otherwise returns updated counts

**`_advance_to_next_song`**: now accepts optional `skip_repo` and calls `clear_skip_requests` on every advance path so skip counts reset for every song change (host skip, `song_finished`, crowdsourced).

**`get_current_session_for_user`**, **`create_session_for_user`**, **`join_session_by_code`**: all now fetch and return `skip_request_count`, `participant_count`, `user_requested_skip` so the first response is always accurate (no stale `participant_count: 1` on initial load).

### New endpoint

```
POST /api/v1/sessions/request_skip
Response: { ok, skip_request_count, participant_count, skipped }
```

No host check — any authenticated session member can call it.

### Updated schema: `CurrentSessionResponse`

Added three new fields (all with safe defaults so old API responses decode cleanly):

```python
skip_request_count: int = 0
participant_count: int = 1
user_requested_skip: bool = False
```

---

## iOS

### `Session.swift`

- `CurrentSessionResponse` gains `skipRequestCount`, `participantCount`, `userRequestedSkip` with `decodeIfPresent` / defaults for backward compatibility
- New `SkipResponse` model: `{ ok, skipRequestCount, participantCount, skipped }`

### `QueueAPIService.swift`

```swift
func requestSkip() async throws -> SkipResponse
// POST /api/v1/sessions/request_skip
```

### `SessionCoordinator.swift`

**`requestSkip()`**:
- Calls API
- Always applies optimistic counts immediately (when `skipped == true`, sets `skipRequestCount = participantCount` so the bar shows full)
- If `skipped == true`: waits 700 ms (so animation is visible) then calls `refreshSession()`

**`refreshSession()`**:
- Detects crowdsourced skip on other clients: if `songChanged && prevSkipCount >= prevParticipantCount / 2`, briefly pins the full bar for 700 ms before applying the new session state — giving non-requester users the same visual feedback

### `RealtimeService.swift`

Added `skip_requests` Postgres change listener (requires table in `supabase_realtime` publication — see migration above).

**Debounce redesign**: all four listeners now call a synchronous `nonisolated handleChange(source:)` which hops to the main actor via `Task { [weak self] in await self?.scheduleRefresh(source:) }`. `scheduleRefresh` cancels any pending task and creates a new debounced one (150 ms window). This:

- Fixes "Publishing changes from background threads" warnings caused by multiple simultaneous events (bulk DELETE on `skip_requests` fires one event per row)
- Coalesces event bursts into a single `refreshSession()` call
- Is Swift 6 safe — no `@MainActor` inference chains, no captured `var self`

### `NowPlayingCard.swift`

New skip section below the vote buttons:

- **Button**: "Request to Skip" / "Skip Requested" (capsule, disabled + checkmark when already requested)
- **Progress bar**: fills as `skipRequestCount / participantCount`, turns coral when > 50%
- **Label**: `"x/y players have requested to skip"` + `"Over 50% skips"` hint

---

## Key decisions

| Decision | Rationale |
|----------|-----------|
| SECURITY DEFINER RPC for the full advance | Participants can't UPDATE `sessions` — widening RLS would expose `host_id`, `join_code`, etc. |
| Composite PK on `skip_requests` | One request per user per song cycle, enforced at DB level |
| Clear requests inside `_advance_to_next_song` | Ensures counts reset on every song change regardless of how it was triggered |
| Debounce realtime refreshes (150 ms) | Bulk DELETE on `skip_requests` fires N events; debounce coalesces into one `refreshSession()` |
| 700 ms pause before refresh on skip | Gives all clients (requester and observers) time to see the full bar before the next song loads |
| `>= 50%` threshold check before showing bar animation on observers | Avoids false positives when song ends naturally while a small number of skip requests were pending |
