# Bug: Guest's First Song Never Transitions to "Playing"

## Summary

When a guest added the first song to an empty queue, the session never moved into the `playing` state. The song stayed stuck in `queued` status, `sessions.current_song` remained `NULL`, and music never started on the host device.

---

## Root Cause

The backend auto-play logic ran two sequential database writes after inserting the first song:

1. `UPDATE sessions SET current_song = <id> WHERE current_song IS NULL` — to claim the now-playing slot
2. `UPDATE queued_songs SET status = 'playing' WHERE id = <id>` — to mark the song as playing

Both writes ran through a **user-authenticated Supabase client**, meaning Supabase enforced RLS with `auth.uid()` = the guest's user ID. The RLS policies for both tables restrict `UPDATE` to the **host only**:

```sql
-- sessions: only host can update
CREATE POLICY sessions_update_host ON public.sessions
FOR UPDATE USING (host_id = auth.uid());

-- queued_songs: only host can update status
CREATE POLICY queued_songs_update_host ON public.queued_songs
FOR UPDATE USING (session_id IN (SELECT id FROM public.sessions WHERE host_id = auth.uid()));
```

Supabase **silently rejects** an RLS-blocked `UPDATE` — it returns empty data with no error, identical to a genuine no-rows-matched result. So the backend interpreted the blocked write as "current_song was already set", skipped the status update, and returned `200 OK`. The database was never changed.

### Silent Failure Chain

| Step | Expected | Actual |
|---|---|---|
| Guest adds first song | Song inserted as `queued` | ✅ Succeeds (INSERT allowed by member RLS) |
| `set_current_song_if_empty` | Returns `True`, sets `current_song` | ❌ RLS blocks UPDATE, returns `False` silently |
| `update_song_status("playing")` | Marks song as `playing` | ❌ Never called (guarded by `was_set`) |
| `sessions.current_song` | Set to new song's ID | ❌ Stays `NULL` |
| iOS `refreshSession()` | Returns new current song | ❌ Returns `current_song: null` |
| `handleSessionChange` on host | Triggers `playTrack` | ❌ Old and new `currentSong` both `nil`, no change detected |
| Music playback | Starts | ❌ Never starts |

---

## Fix

The same pattern already used by `crowdsourced_skip_advance` — a **`SECURITY DEFINER` PostgreSQL RPC** that executes with elevated privileges (schema owner), bypassing the user-level RLS.

### 1. New SQL migration: `20260318_autoplay_first_song_rpc.sql`

```sql
CREATE OR REPLACE FUNCTION autoplay_first_song(p_session_id UUID, p_queued_song_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE sessions
    SET current_song = p_queued_song_id
    WHERE id = p_session_id
      AND current_song IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RETURN FALSE;
    END IF;

    UPDATE queued_songs
    SET status = 'playing'
    WHERE id = p_queued_song_id;

    RETURN TRUE;
END;
$$;
```

The `WHERE current_song IS NULL` guard also preserves race-condition safety — if two guests add songs simultaneously, only one wins the atomic update.

### 2. `session_repo.py` — replaced `set_current_song_if_empty` with `autoplay_first_song`

The new method calls the RPC via `.rpc()` instead of a direct table `UPDATE`.

### 3. `queue_service.py` — updated call site

Replaced the two-step `set_current_song_if_empty` + `update_song_status` calls with a single `autoplay_first_song` call. The RPC handles both writes atomically, so the separate status update was removed.

---

## Files Changed

| File | Change |
|---|---|
| `supabase/migrations/20260318_autoplay_first_song_rpc.sql` | New — `SECURITY DEFINER` RPC |
| `QueueITbackend/app/repositories/session_repo.py` | Replaced `set_current_song_if_empty` with `autoplay_first_song` |
| `QueueITbackend/app/services/queue_service.py` | Updated call site to use new repo method |
