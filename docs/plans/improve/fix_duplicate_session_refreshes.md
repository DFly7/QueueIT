# Fix Single-Client Duplicate GET /sessions/current on Remove Vote

## Root Cause

The timestamps show **2 GETs per delete** (~17ms apart), not 4 from one delete. The 4 total GETs come from 2 separate remove-vote actions:

| Delete (GMT) | GETs (GMT)     |
| ------------ | -------------- |
| 31.711       | 32.196, 32.213 |
| 35.192       | 35.658, 35.689 |

For each remove-vote, two Supabase Realtime events are emitted:

1. **votes table** – the `DELETE` of the vote row
2. **queued_songs table** – the `UPDATE` from the `tr_queue_tier_sorting` trigger (see [supabase/migrations/20260315_queue_tier_sorting.sql](../../supabase/migrations/20260315_queue_tier_sorting.sql))

Both events call `handleChange` → `scheduleRefresh` in [RealtimeService.swift](../../QueueIT/QueueIT/Services/RealtimeService.swift). The 150ms debounce should merge them, but they still produce 2 refreshes, likely because:

- Events arrive far enough apart (e.g. >150ms) that both fire `refreshSession`, or
- There is a race with task cancellation (one task already past sleep before being cancelled)

## Solution: Remove Redundant votes Listener

Every vote change (INSERT/UPDATE/DELETE) is reflected in `queued_songs` by the trigger. Keeping only the `queued_songs` listener:

- Covers vote changes via the trigger
- Drops from 2 events to 1 per vote change
- Reduces GET /sessions/current from 2 to 1 per remove-vote (and per add-vote)

The votes listener is redundant for session sync; `queued_songs` is already the source of truth for vote counts and tier metadata.

## Implementation

Edit [QueueIT/QueueIT/Services/RealtimeService.swift](../../QueueIT/QueueIT/Services/RealtimeService.swift):

1. **Remove the votes listener** (lines 71–81):

   - Drop the `onPostgresChange(..., table: "votes")` block
   - Leave the comment explaining why votes are omitted: the trigger always updates `queued_songs`

2. **Optional: strengthen debounce** – If other duplicate refreshes appear (e.g. skip_requests), consider increasing the debounce from 150ms to 250–300ms in `scheduleRefresh`. Not required for this fix.

## Verification

- Remove two votes and confirm only 2 GETs total (1 per remove) instead of 4.
- Add votes and change votes; session should still update correctly via the `queued_songs` listener.
