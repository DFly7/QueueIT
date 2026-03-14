-- Migration: Add is_anonymous flag to public.users
--
-- Supabase already tracks this on auth.users, but surfacing it on the profile
-- table means the iOS app and backend can read it from a normal profile fetch
-- without a separate auth lookup.
--
-- Run in: Supabase SQL editor → New query → Run

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_anonymous boolean NOT NULL DEFAULT false;

-- Back-fill any existing anonymous users by joining against auth.users
-- (safe to run even if no anonymous users exist yet)
UPDATE public.users pu
SET    is_anonymous = au.is_anonymous
FROM   auth.users au
WHERE  pu.id = au.id
  AND  au.is_anonymous = true;

-- Optional: index for fast "show me all guests in this session" queries
CREATE INDEX IF NOT EXISTS idx_users_is_anonymous ON public.users (is_anonymous);
