-- Migration: delete_user_data RPC
-- Atomically removes all public data for a user before the auth user is deleted.
-- Called by the backend admin client; SECURITY DEFINER bypasses RLS.

CREATE OR REPLACE FUNCTION public.delete_user_data(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Unlink user from current session
  UPDATE users SET current_session = NULL WHERE id = p_user_id;

  -- 2. Clear current_song on sessions this user hosts (avoid FK violation when deleting queued_songs)
  UPDATE sessions SET current_song = NULL WHERE host_id = p_user_id;

  -- 3. Delete votes by this user
  DELETE FROM votes WHERE user_id = p_user_id;

  -- 4. Delete votes on queued_songs we're about to remove
  DELETE FROM votes WHERE queued_song_id IN (
    SELECT id FROM queued_songs
    WHERE added_by_id = p_user_id OR session_id IN (SELECT id FROM sessions WHERE host_id = p_user_id)
  );

  -- 5. Delete queued_songs (user's additions + songs in sessions they host)
  DELETE FROM queued_songs
  WHERE added_by_id = p_user_id OR session_id IN (SELECT id FROM sessions WHERE host_id = p_user_id);

  -- 6. Delete sessions this user hosts
  DELETE FROM sessions WHERE host_id = p_user_id;

  -- 7. Delete user row (skip_requests ON DELETE CASCADE fires automatically)
  DELETE FROM users WHERE id = p_user_id;
END;
$$;
