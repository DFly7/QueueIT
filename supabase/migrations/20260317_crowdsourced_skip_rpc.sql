-- SECURITY DEFINER RPC for the full crowdsourced-skip advance.
-- Regular participants cannot UPDATE queued_songs or sessions via RLS, so this
-- function runs with elevated privileges to:
--   1. Mark the current song as 'skipped'
--   2. Clear all skip requests for the session
--   3. Find the next queued song (using the same tier-sort as the Python layer)
--   4. Mark it as 'playing'
--   5. Update sessions.current_song
-- Returns the new current queued_song id, or NULL if the queue is empty.

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

    -- 3. Find the next song using the same tier-sort as the Python layer:
    --    votes DESC → entered_tier_by_gain ASC (losers first) →
    --    last_entered_tier_at ASC for gainers / DESC for losers →
    --    created_at ASC tie-breaker
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

    -- 5. Update the session's current_song (NULL if queue is empty)
    UPDATE sessions
    SET current_song = v_next_song_id
    WHERE id = p_session_id;

    RETURN v_next_song_id;
END;
$$;
