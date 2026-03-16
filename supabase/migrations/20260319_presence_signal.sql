-- Dedicated presence signal on sessions; only updated when the room population changes.
-- Keeps any future updated_at audit column clean.
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS last_presence_change timestamptz DEFAULT now();

-- UX: remember the last session a user was in (enables "rejoin" flows).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS previous_session_id uuid REFERENCES public.sessions(id);

-- SECURITY DEFINER RPC so any session member (not just the host) can bump
-- last_presence_change. Direct UPDATE on sessions is blocked by sessions_update_host
-- RLS for non-host users, which would silently no-op and fire no CDC event.
CREATE OR REPLACE FUNCTION touch_session_presence(p_session_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE sessions
  SET last_presence_change = now()
  WHERE id = p_session_id;
$$;
