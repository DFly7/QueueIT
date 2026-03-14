# Queue Tier Sorting — Implementation Summary

**Date:** March 15, 2026  
**Status:** Complete

---

## What Was Built

An asymmetric sorting system for the song queue. Within each vote tier, songs are ordered based on **how they arrived** in that tier, not just when they were added.

### The Rule

| How the song entered the tier | Position within tier |
|-------------------------------|----------------------|
| Lost a vote (fell from above) | Top — newest first |
| Gained a vote (rose from below) | Bottom — newest last |
| Newly added (0 votes, never voted) | Bottom of 0-vote tier |
| Tie (same timestamp) | Earlier `added_at` first |

This creates a "sandwich" effect: recent losers at the top, stable songs in the middle, recent gainers at the bottom.

### Example (5-vote tier)

| Position | Song | Reason |
|----------|------|--------|
| 1 (Top) | Song A | Just dropped from 6 → 5 |
| 2 | Song B | Dropped from 6 → 5 earlier |
| 3 | Song C | Stable at 5 for an hour |
| 4 | Song D | Rose from 4 → 5 earlier |
| 5 (Bottom) | Song E | Just rose from 4 → 5 |

---

## Files Changed

### Database

**`supabase/migrations/20260315_queue_tier_sorting.sql`**
- Adds `last_entered_tier_at timestamptz` and `entered_tier_by_gain boolean` to `queued_songs`
- Backfills existing rows using `created_at` (the live DB column name) and `true`
- Creates `update_queue_tier_metadata()` trigger function on the `votes` table
- Attaches it as `tr_queue_tier_sorting` (AFTER INSERT OR UPDATE OR DELETE)

**`supabase/schema.sql`**
- Updated to reflect the two new columns, their defaults and comments
- Added the trigger function and trigger definition

### Backend

**`QueueITbackend/app/repositories/queue_repo.py`**
- `add_song_to_queue`: includes `entered_tier_by_gain = True` in insert (new songs go to bottom of 0-vote tier)
- `vote_on_song` / `remove_vote`: **no changes** — the DB trigger handles metadata atomically
- `list_session_queue`:
  - Selects `last_entered_tier_at` and `entered_tier_by_gain` from the DB row
  - Maps `created_at` to `added_at` in the view dict (the live DB column is `created_at`)
  - Applies the asymmetric `_tier_sort_key` instead of the old flat sort

**`QueueITbackend/app/schemas/session.py`**
- `QueuedSongResponse` gains `last_entered_tier_at: Optional[datetime]` and `entered_tier_by_gain: bool = True`
- Added `serialize_tier_datetime` field serializer for iOS compatibility

**`QueueITbackend/app/services/queue_service.py`** and **`session_service.py`**
- Both `_map_queue_item` functions pass the two new fields into `QueuedSongResponse`

### iOS

**`QueueIT/QueueIT/Models/Session.swift`**
- `QueuedSongResponse` gains `lastEnteredTierAt: Date?` (default `nil`) and `enteredTierByGain: Bool` (default `true`)
- `Codable` conformance moved to an extension — this preserves the compiler-generated memberwise initializer, which is needed for creating optimistic pending songs in `addSong`
- `decodeIfPresent` used for both new fields so the model handles older API responses gracefully

**`QueueIT/QueueIT/Services/SessionCoordinator.swift`**
- `optimisticTierMetadata: [UUID: (byGain: Bool, at: Date)]` dict added
- `queue` computed property uses a two-step approach:
  1. Sort all songs by server data (votes → gain/loss flag → timestamp → addedAt)
  2. Post-sort: for any song in `optimisticTierMetadata`, pull it out and re-insert at the correct tier boundary (top for losers, bottom for gainers)
- `populateDisplayedVoteCounts` clears `optimisticTierMetadata` entries for non-in-flight songs when a session refresh arrives

---

## Key Design Decisions

### Trigger on `votes`, not `queued_songs`

The intuitive trigger placement would be `BEFORE UPDATE ON queued_songs` (as suggested in the original plan review). This doesn't work because **`queued_songs` has no `votes` column**. Votes live in a separate `votes` table and are aggregated at query time. The trigger must fire on `votes` (AFTER INSERT OR UPDATE OR DELETE) and update `queued_songs` from there.

### Delta arithmetic in the trigger (no extra aggregate query)

The trigger computes `new_total` via `SUM(vote_value)` after the change, then reconstructs `old_total` using the delta:

```sql
-- INSERT: old_total = new_total - NEW.vote_value
-- UPDATE: old_total = new_total - NEW.vote_value + OLD.vote_value
-- DELETE: old_total = new_total + OLD.vote_value
```

This avoids a second `SUM` query per vote, and because the arithmetic runs inside the trigger (within the same transaction), it is race-condition-free. No Python fetch-before/update-after logic is needed.

### `created_at` vs `added_at`

The `queued_songs` table column in the live DB is `created_at`. The backend view model renames it to `added_at` when building view rows (`"added_at": row["created_at"]`). The migration backfill must use `created_at` — using `added_at` in the SQL causes a column-not-found error.

### Two-step sort in the iOS client

A naive approach puts `optimisticTierMetadata` values directly into the sort comparator closure. This causes the sort algorithm to produce inconsistent results because it calls the comparator in unpredictable order. The fix is:

1. Sort everything cleanly using server data (stable)
2. After sorting, do a simple `remove(at:)` + `insert(at:)` for any song with optimistic tier metadata

### When to clear `optimisticTierMetadata`

The metadata must **not** be cleared when the POST `/vote` returns. At that point `GET /sessions/current` hasn't landed yet, so `currentSession` still has the old `enteredTierByGain`. Clearing early causes a ~500ms window where the song sorts by stale server data (wrong position).

The metadata is cleared inside `populateDisplayedVoteCounts` — which is called every time a session refresh lands. By then, the server has the correct `enteredTierByGain` and `lastEnteredTierAt`, so clearing is safe and the next queue evaluation uses accurate server data.

### Loop over `optimisticTierMetadata`, not `votesInFlight`

The post-sort repositioning must loop over `optimisticTierMetadata`, not `votesInFlight`. `votesInFlight` is cleared as soon as the POST returns (before the session refresh). If the loop uses `votesInFlight`, it finds no songs to reposition in the window between POST response and session refresh, causing the same snap.

---

## Optimistic UI Flow (Final)

```
User taps vote
    → optimisticTierMetadata[id] = (byGain, now)
    → votesInFlight.insert(id)
    → displayedVoteCounts[id] updated
    → queue recomputes: sort + remove/insert → correct position ✓

POST /vote returns
    → votesInFlight.remove(id)        ← optimisticTierMetadata kept
    → displayedVoteCounts[id] = server total
    → queue recomputes: sort + remove/insert (from optimisticTierMetadata) → correct position ✓

GET /sessions/current arrives (~500ms later)
    → populateDisplayedVoteCounts:
        displayedVoteCounts[id] = server total
        optimisticTierMetadata.removeValue(id)   ← now safe to clear
    → queue recomputes: sort by server data (enteredTierByGain now correct) → correct position ✓
```
