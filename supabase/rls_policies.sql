-- RLS Policy Scaffolding (review and adapt before enabling)
-- Enable RLS on all tables once policies are defined

-- Example assumptions:
-- - auth.uid() matches public.users.id
-- - Membership is derived by users.current_session matching sessions.id

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queued_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;

-- Users: a user may select their own row; host can be any user
CREATE POLICY users_select_self ON public.users
FOR SELECT
USING (id = auth.uid());

-- Sessions: visible to users who are host or whose current_session matches
CREATE POLICY sessions_select_members ON public.sessions
FOR SELECT
USING (
  host_id = auth.uid()
  OR id = (SELECT current_session FROM public.users WHERE id = auth.uid())
);

-- Sessions: host can update their session
CREATE POLICY sessions_update_host ON public.sessions
FOR UPDATE
USING (host_id = auth.uid())
WITH CHECK (host_id = auth.uid());

-- Queued Songs: visible to members of the session
CREATE POLICY queued_songs_select_members ON public.queued_songs
FOR SELECT
USING (
  session_id = (SELECT current_session FROM public.users WHERE id = auth.uid())
);

-- Queued Songs: insert allowed for members of active session
CREATE POLICY queued_songs_insert_members ON public.queued_songs
FOR INSERT
WITH CHECK (
  added_by_id = auth.uid()
  AND session_id = (SELECT current_session FROM public.users WHERE id = auth.uid())
);

-- Queued Songs: host can update song status (for skip, next song, etc.)
CREATE POLICY queued_songs_update_host ON public.queued_songs
FOR UPDATE
USING (session_id IN (SELECT id FROM public.sessions WHERE host_id = auth.uid()))
WITH CHECK (session_id IN (SELECT id FROM public.sessions WHERE host_id = auth.uid()));

-- Votes: members can insert/update their own votes
CREATE POLICY votes_insert_members ON public.votes
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
  AND queued_song_id IN (
    SELECT qs.id
    FROM public.queued_songs qs
    WHERE qs.session_id = (SELECT current_session FROM public.users WHERE id = auth.uid())
  )
);

CREATE POLICY votes_update_owner ON public.votes
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Songs: global read allowed (no user data)
CREATE POLICY songs_select_all ON public.songs
FOR SELECT USING (true);

-- Songs: authenticated users can insert new songs
CREATE POLICY songs_insert_authenticated ON public.songs
FOR INSERT
WITH CHECK (true);

-- Songs: authenticated users can update songs (for upserts)
CREATE POLICY songs_update_authenticated ON public.songs
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Note: Consider adding a separate membership table for more flexible membership management.


