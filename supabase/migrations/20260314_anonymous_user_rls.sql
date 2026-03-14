-- Migration: Allow anonymous Supabase users (App Clip guests) to read/write their own data
-- Run this in the Supabase SQL editor or via `supabase db push`.
--
-- What changed and why:
--
--  1. users INSERT  — signInAnonymously() upserts a profile row; there was no INSERT policy.
--  2. users UPDATE  — guests may update their own username (name prompt); also needed by
--                     the backend's join-session flow which sets current_session.
--  3. sessions SELECT — added a direct join_code path so a guest can read a session
--                       immediately after joining (before current_session propagates).
--  4. votes DELETE  — needed so remove-vote works (the backend may delete rather than update).
--
-- All policies use auth.uid() which works identically for both real and anonymous Supabase users.

-- ─── users ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS users_insert_self ON public.users;
CREATE POLICY users_insert_self ON public.users
FOR INSERT
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS users_update_self ON public.users;
CREATE POLICY users_update_self ON public.users
FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ─── sessions ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS sessions_select_members ON public.sessions;
CREATE POLICY sessions_select_members ON public.sessions
FOR SELECT
USING (
  host_id = auth.uid()
  OR id = (SELECT current_session FROM public.users WHERE id = auth.uid())
  OR id IN (
    SELECT session_id
    FROM public.queued_songs
    WHERE added_by_id = auth.uid()
    LIMIT 1
  )
);

-- ─── votes ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS votes_delete_owner ON public.votes;
CREATE POLICY votes_delete_owner ON public.votes
FOR DELETE
USING (user_id = auth.uid());

DROP POLICY IF EXISTS votes_select_members ON public.votes;
CREATE POLICY votes_select_members ON public.votes
FOR SELECT
USING (
  user_id = auth.uid()
  OR queued_song_id IN (
    SELECT qs.id
    FROM public.queued_songs qs
    WHERE qs.session_id = (SELECT current_session FROM public.users WHERE id = auth.uid())
  )
);
