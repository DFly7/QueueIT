-- Migration: Get User Votes for Session (RPC)
--
-- Adds a PostgreSQL function that returns a user's votes for all songs in a given
-- session in a single efficient JOIN query.
--
-- Why RPC instead of a client-side IN query:
--   - Atomic: no race between queue fetch and vote fetch.
--   - Efficient: single native JOIN vs. two round-trips with an IN list.
--   - Safe: SECURITY INVOKER means the function runs as the caller so all
--     existing RLS policies on the votes and queued_songs tables still apply.
--     Even if the WHERE clause had a bug, a user can never read another
--     user's votes because RLS on votes_select_members enforces user_id = auth.uid().

CREATE OR REPLACE FUNCTION public.get_user_votes_for_session(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS TABLE (queued_song_id uuid, vote_value integer)
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT v.queued_song_id, v.vote_value
  FROM votes v
  JOIN queued_songs qs ON v.queued_song_id = qs.id
  WHERE qs.session_id = p_session_id
    AND v.user_id = p_user_id;
$$;
