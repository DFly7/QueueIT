-- Migration: Crowdsourced skip requests

-- Table to track who has requested to skip the current song
CREATE TABLE IF NOT EXISTS skip_requests (
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT skip_requests_pkey PRIMARY KEY (session_id, user_id)
);

-- RLS: users can only interact with skip_requests for their current session
ALTER TABLE skip_requests ENABLE ROW LEVEL SECURITY;

-- INSERT: a user may request a skip if they are currently in that session
CREATE POLICY "Users can insert their own skip request"
    ON skip_requests FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND session_id = (
            SELECT current_session FROM users WHERE id = auth.uid()
        )
    );

-- SELECT: session members can read all skip requests in their session
CREATE POLICY "Users can view skip requests in their session"
    ON skip_requests FOR SELECT
    USING (
        session_id = (
            SELECT current_session FROM users WHERE id = auth.uid()
        )
    );

-- DELETE: service role / SECURITY DEFINER functions handle bulk clears
CREATE POLICY "Users can delete their own skip request"
    ON skip_requests FOR DELETE
    USING (
        user_id = auth.uid()
        AND session_id = (
            SELECT current_session FROM users WHERE id = auth.uid()
        )
    );

-- RPC: count participants in a session
-- SECURITY DEFINER so it can read other users' rows regardless of RLS
CREATE OR REPLACE FUNCTION get_session_participant_count(p_session_id UUID)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)::INTEGER
    FROM users
    WHERE current_session = p_session_id;
$$;

-- RPC: count skip requests for a session (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION get_session_skip_request_count(p_session_id UUID)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)::INTEGER
    FROM skip_requests
    WHERE session_id = p_session_id;
$$;

-- RPC: clear all skip requests for a session (called on song advance)
CREATE OR REPLACE FUNCTION clear_skip_requests(p_session_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    DELETE FROM skip_requests WHERE session_id = p_session_id;
$$;

-- RPC: check whether a specific user has requested a skip
CREATE OR REPLACE FUNCTION user_has_skip_request(p_session_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM skip_requests
        WHERE session_id = p_session_id AND user_id = p_user_id
    );
$$;
