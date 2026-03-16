# Crowdsourced Skip — Updated Implementation Notes

Supersedes bug-fix work done after the original [`implementation.md`](./implementation.md).

---

## Bug: Skip bar animation only fired on the final voter (3+ players)

### Root cause

`refreshSession()` in `SessionCoordinator.swift` used a heuristic to decide whether to show the full-bar animation before the song changed:

```swift
let skipWasAtThreshold = Double(prevSkipCount) >= Double(prevParticipantCount) / 2.0
```

With **2 players** this accidentally worked — the first voter saw `1/2 = 50%`, which satisfied `>= 50%`.

With **3+ players** it broke — non-final voters only ever saw the pre-final count (e.g. `1/3 = 33%`) because the final vote and the skip advance execute atomically on the backend. The `>= 50%` check always evaluated `false` for them, so only the device that cast the tipping vote saw the bar fill.

### Fix: explicit `last_skip_was_crowdsourced` flag

Replace the heuristic with a backend-owned boolean so there is nothing to infer on the client.

---

## Changes

### Migration `supabase/migrations/20260320_crowdsourced_skip_reason.sql`

- Adds `sessions.last_skip_was_crowdsourced boolean NOT NULL DEFAULT false`
- Rewrites `crowdsourced_skip_advance` RPC to set it `true` in the same transaction that advances the song
- `SessionRepository.set_current_song()` (Python) resets it to `false` on every non-crowdsourced advance (host skip, natural song end)

### `session_repo.py`

`set_current_song` now writes `last_skip_was_crowdsourced: False` alongside `current_song` so all host-driven and natural advances clear the flag atomically.

### `app/schemas/session.py`

Added to `CurrentSessionResponse`:
```python
last_skip_was_crowdsourced: bool = False
```

### `session_service.py`

All three `CurrentSessionResponse(...)` call sites (`get_current_session_for_user`, `create_session_for_user`, `join_session_by_code`) now pass:
```python
last_skip_was_crowdsourced=session_row.get("last_skip_was_crowdsourced", False)
```

### `Session.swift`

`CurrentSessionResponse` gains `lastSkipWasCrowdsourced: Bool = false` with a `decodeIfPresent` fallback so old API responses decode cleanly.

### `SessionCoordinator.swift` — `refreshSession()`

The old heuristic is gone. The condition is now:

```swift
if songChanged && newSession.lastSkipWasCrowdsourced {
    // pin full bar for 700 ms on all devices
}
```

---

## Behaviour matrix

| Scenario | `last_skip_was_crowdsourced` | Full-bar animation |
|---|---|---|
| Crowdsourced skip (any group size) | `true` | ✅ all connected devices |
| Host taps "Skip Current Track" | `false` | ✅ no animation |
| Song ends naturally (0 pending skips) | `false` | ✅ no animation |
| Song ends naturally (1+ pending skips) | `false` | ✅ no animation (false-positive fixed) |

---

## Why a DB column rather than an iOS heuristic

Any client-side check based on `prevSkipCount` is racing against an atomic backend transaction. The final `skip_request_count` that triggered the skip is never delivered to non-final voters before the song changes — they only see the state from the previous `refreshSession()` call. Storing the intent on the sessions row makes it a first-class fact that every client reads in the same `GET /sessions/current` response that delivers the new song.
