-- Explicit flag so iOS clients can distinguish a crowdsourced skip from a
-- natural song end without relying on a prevSkipCount heuristic.
-- Set to TRUE by crowdsourced_skip_advance; reset to FALSE by all other
-- advance paths (host skip, song_finished) via set_current_song.
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS last_skip_was_crowdsourced boolean NOT NULL DEFAULT false;

-- Redefine crowdsourced_skip_advance to also set the flag.
-- All other fields are unchanged from 20260317_crowdsourced_skip_rpc.sql.
CREATE OR REPLACE FUNCTION crowdsourced_skip_advance(p_session_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_song_id UUID;
    v_next_song_id    UUID;
BEGIN
    -- 1. Get and skip the currently playing song
    SELECT current_song INTO v_current_song_id
    FROM sessions
    WHERE id = p_session_id;

    IF v_current_song_id IS NOT NULL THEN
        UPDATE queued_songs
        SET status = 'skipped'
        WHERE id = v_current_song_id;
    END IF;

    -- 2. Clear all skip requests for this session
    DELETE FROM skip_requests WHERE session_id = p_session_id;

    -- 3. Find the next song (same tier-sort as the Python layer)
    SELECT qs.id INTO v_next_song_id
    FROM queued_songs qs
    LEFT JOIN (
        SELECT queued_song_id, COALESCE(SUM(vote_value), 0) AS total_votes
        FROM votes
        GROUP BY queued_song_id
    ) v ON v.queued_song_id = qs.id
    WHERE qs.session_id = p_session_id
      AND qs.status = 'queued'
    ORDER BY
        COALESCE(v.total_votes, 0) DESC,
        qs.entered_tier_by_gain ASC,
        CASE WHEN qs.entered_tier_by_gain = false
             THEN qs.last_entered_tier_at END DESC,
        CASE WHEN qs.entered_tier_by_gain = true
             THEN qs.last_entered_tier_at END ASC,
        qs.created_at ASC
    LIMIT 1;

    -- 4. Mark the next song as playing (if one exists)
    IF v_next_song_id IS NOT NULL THEN
        UPDATE queued_songs
        SET status = 'playing'
        WHERE id = v_next_song_id;
    END IF;

    -- 5. Advance current_song and mark this as a crowdsourced skip
    UPDATE sessions
    SET current_song = v_next_song_id,
        last_skip_was_crowdsourced = true
    WHERE id = p_session_id;

    RETURN v_next_song_id;
END;
$$;
