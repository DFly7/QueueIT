-- Supabase Realtime Configuration for QueueIT
-- This enables real-time synchronization of votes, queue changes, and session updates
-- across multiple users in the same session.

-- Enable Realtime on tables needed for multi-user sync
-- Run this once per environment (already applied to production)

ALTER PUBLICATION supabase_realtime ADD TABLE votes, queued_songs, sessions;

-- Verify Realtime is enabled (should return rows for each table)
-- SELECT schemaname, tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';

-- Notes:
-- 1. Row Level Security (RLS) is enforced for Realtime events
--    Users only receive events for rows they have SELECT access to
--
-- 2. The following tables are enabled:
--    - votes: Sync vote counts across all session members
--    - queued_songs: Sync queue additions and status changes
--    - sessions: Sync current_song changes and session settings
--
-- 3. For DELETE events with RLS enabled, only primary keys are sent
--    (not the full row data) for security reasons
--
-- 4. To receive old record values on UPDATE/DELETE, enable replica identity:
--    ALTER TABLE votes REPLICA IDENTITY FULL;
--    ALTER TABLE queued_songs REPLICA IDENTITY FULL;
--    ALTER TABLE sessions REPLICA IDENTITY FULL;
--    (Not currently needed for QueueIT's refresh-based approach)
