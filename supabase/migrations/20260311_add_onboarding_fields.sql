-- Migration: Add onboarding and music provider fields
-- Created: 2026-03-11
-- Description: Adds music_provider, spotify_refresh_token, storefront to users table
--              and host_provider to sessions table for onboarding flow

-- Add columns to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS music_provider VARCHAR(20) NOT NULL DEFAULT 'none' 
  CHECK (music_provider IN ('apple', 'spotify', 'none')),
ADD COLUMN IF NOT EXISTS spotify_refresh_token TEXT,
ADD COLUMN IF NOT EXISTS storefront VARCHAR(10) DEFAULT 'us';

-- Add column to sessions table
ALTER TABLE public.sessions 
ADD COLUMN IF NOT EXISTS host_provider VARCHAR(20) NOT NULL DEFAULT 'spotify'
  CHECK (host_provider IN ('apple', 'spotify'));

-- Update the auth trigger to set default music_provider
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, music_provider)
  VALUES (NEW.id, 'none')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure the trigger exists (idempotent)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Add comments for documentation
COMMENT ON COLUMN public.users.music_provider IS 'User''s music streaming service: apple, spotify, or none';
COMMENT ON COLUMN public.users.spotify_refresh_token IS 'Encrypted Spotify refresh token for OAuth (if provider is spotify)';
COMMENT ON COLUMN public.users.storefront IS 'Apple Music storefront/region code (e.g., us, gb, ca)';
COMMENT ON COLUMN public.sessions.host_provider IS 'Host''s music provider for this session (apple or spotify)';
