-- Migration: Update handle_new_user trigger to copy is_anonymous from auth.users
--
-- Without this, the trigger creates the public.users row with is_anonymous = false
-- (the column default), and the iOS signInAnonymously upsert must run afterwards
-- to correct it. This migration makes the trigger authoritative so the column is
-- correct from the moment of creation, with no race window.
--
-- Run in: Supabase SQL editor → New query → Run

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, music_provider, is_anonymous)
  VALUES (NEW.id, 'none', COALESCE(NEW.is_anonymous, false))
  ON CONFLICT (id) DO UPDATE
    SET is_anonymous = EXCLUDED.is_anonymous;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- The trigger itself does not need to be recreated (it still fires AFTER INSERT ON auth.users).
-- Re-creating the function is sufficient.
