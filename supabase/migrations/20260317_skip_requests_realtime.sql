-- Enable Supabase Realtime for the skip_requests table.
-- Without this, subscribing to Postgres changes on this table causes the
-- entire realtime channel to fail (the table must be in the publication).
ALTER PUBLICATION supabase_realtime ADD TABLE skip_requests;
