-- Migration: Asymmetric Queue Tier Sorting
--
-- Adds two columns to queued_songs that track *when* a song entered its current
-- vote count and *how* it got there (by gaining or losing a vote).
--
-- Sort rule within each tier:
--   - Songs that fell into the tier (lost a vote) → top, newest first
--   - Songs that rose into the tier (gained a vote) → bottom, newest last
--   - Tie-breaker: created_at (exposed as added_at in the view) ASC
--
-- A trigger on the `votes` table keeps the metadata atomically in sync
-- whenever votes are inserted, updated, or deleted, without any extra roundtrips
-- from the Python layer.
--
-- Run in: Supabase SQL editor → New query → Run

-- ─── Step 1: Add columns ─────────────────────────────────────────────────────

ALTER TABLE public.queued_songs
  ADD COLUMN IF NOT EXISTS last_entered_tier_at timestamptz,
  ADD COLUMN IF NOT EXISTS entered_tier_by_gain boolean;

-- ─── Step 2: Backfill existing rows ──────────────────────────────────────────
-- Treat all existing songs as if they "rose" into their tier (bottom of tier).
-- Use created_at (the actual live DB column) so the original order is preserved.

UPDATE public.queued_songs
SET
  last_entered_tier_at = created_at,
  entered_tier_by_gain = true
WHERE last_entered_tier_at IS NULL;

-- ─── Step 3: Make columns non-nullable with defaults ─────────────────────────

ALTER TABLE public.queued_songs
  ALTER COLUMN last_entered_tier_at SET NOT NULL,
  ALTER COLUMN last_entered_tier_at SET DEFAULT now(),
  ALTER COLUMN entered_tier_by_gain SET NOT NULL,
  ALTER COLUMN entered_tier_by_gain SET DEFAULT true;

COMMENT ON COLUMN public.queued_songs.last_entered_tier_at IS
  'Timestamp when the song last moved to its current vote count (tier). Updated atomically by trigger on the votes table.';
COMMENT ON COLUMN public.queued_songs.entered_tier_by_gain IS
  'True if the song entered its current tier by gaining a vote (sorts to bottom of tier). False if it fell by losing a vote (sorts to top of tier).';

-- ─── Step 4: Trigger function on votes ───────────────────────────────────────
-- Fires AFTER any change to the votes table and updates the parent queued_song
-- with the new tier metadata.
--
-- Delta arithmetic avoids an extra aggregate query:
--   INSERT: old_total = new_total − NEW.vote_value
--   UPDATE: old_total = new_total − NEW.vote_value + OLD.vote_value
--   DELETE: old_total = new_total + OLD.vote_value
--
-- Only updates queued_songs when the total actually changes, so flipping from
-- +1 to −1 (net change = −2) is treated as a loss, and vice-versa.

CREATE OR REPLACE FUNCTION public.update_queue_tier_metadata()
RETURNS TRIGGER AS $$
DECLARE
  v_queued_song_id uuid;
  v_new_total      integer;
  v_old_total      integer;
BEGIN
  -- Determine which queued_song_id is affected
  IF TG_OP = 'DELETE' THEN
    v_queued_song_id := OLD.queued_song_id;
  ELSE
    v_queued_song_id := NEW.queued_song_id;
  END IF;

  -- Compute current aggregate (after the triggering change)
  SELECT COALESCE(SUM(vote_value), 0)
    INTO v_new_total
    FROM public.votes
   WHERE queued_song_id = v_queued_song_id;

  -- Reconstruct what the total was before
  IF TG_OP = 'INSERT' THEN
    v_old_total := v_new_total - NEW.vote_value;
  ELSIF TG_OP = 'UPDATE' THEN
    v_old_total := v_new_total - NEW.vote_value + OLD.vote_value;
  ELSE -- DELETE
    v_old_total := v_new_total + OLD.vote_value;
  END IF;

  -- Only write when the total actually shifted (avoids spurious updates)
  IF v_new_total <> v_old_total THEN
    UPDATE public.queued_songs
       SET last_entered_tier_at = now(),
           entered_tier_by_gain = (v_new_total > v_old_total)
     WHERE id = v_queued_song_id;
  END IF;

  RETURN NULL; -- AFTER trigger; return value is ignored
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── Step 5: Attach trigger to votes ─────────────────────────────────────────

DROP TRIGGER IF EXISTS tr_queue_tier_sorting ON public.votes;

CREATE TRIGGER tr_queue_tier_sorting
  AFTER INSERT OR UPDATE OR DELETE ON public.votes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_queue_tier_metadata();
