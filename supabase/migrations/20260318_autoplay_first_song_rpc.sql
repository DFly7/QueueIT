-- SECURITY DEFINER RPC to atomically promote the first song to "playing".
-- Regular participants cannot UPDATE sessions or queued_songs via RLS, so this
-- function runs with elevated privileges to:
--   1. Check if sessions.current_song is NULL
--   2. If so, set it to p_queued_song_id and mark that song as 'playing'
-- Returns TRUE if the song was promoted, FALSE if current_song was already set
-- (i.e. another song beat us to it).

CREATE OR REPLACE FUNCTION autoplay_first_song(p_session_id UUID, p_queued_song_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    -- Atomically claim the current_song slot only if it is still NULL.
    -- This prevents race conditions when multiple guests add songs concurrently.
    UPDATE sessions
    SET current_song = p_queued_song_id
    WHERE id = p_session_id
      AND current_song IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        -- current_song was already set by someone else; nothing to do.
        RETURN FALSE;
    END IF;

    -- We won the race: mark this queued song as 'playing'.
    UPDATE queued_songs
    SET status = 'playing'
    WHERE id = p_queued_song_id;

    RETURN TRUE;
END;
$$;
