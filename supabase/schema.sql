-- QueueIT Database Schema
-- This file reflects the current live schema after all migrations have been applied.
-- Last updated: 2026-03-14
--
-- Migration history (run in order):
--   20260311_add_onboarding_fields.sql      – music_provider, storefront, host_provider, trigger
--   20260314_add_is_anonymous_to_users.sql  – is_anonymous column + backfill
--   20260314_anonymous_user_rls.sql         – INSERT/UPDATE/SELECT/DELETE policies for anon users
--   20260314_fix_trigger_is_anonymous.sql   – trigger now copies is_anonymous from auth.users
--
-- NOTE: Run rls_policies.sql separately to apply all RLS policies.
-- NOTE: Run realtime.sql separately to enable Realtime on the required tables.

-- ─── Custom Types ─────────────────────────────────────────────────────────────

-- Status values for a song in the queue
CREATE TYPE public.queued_song_status AS ENUM (
  'queued',   -- waiting to be played
  'playing',  -- currently playing
  'played',   -- finished playing
  'skipped'   -- skipped by host
);

-- ─── Tables ───────────────────────────────────────────────────────────────────

CREATE TABLE public.users (
  id                    uuid         NOT NULL,
  username              text         UNIQUE,
  created_at            timestamptz  NOT NULL DEFAULT now(),
  current_session       uuid,
  music_provider        varchar(20)  NOT NULL DEFAULT 'none'
                          CHECK (music_provider IN ('apple', 'spotify', 'none')),
  spotify_refresh_token text,
  storefront            varchar(10)  DEFAULT 'us',
  is_anonymous          boolean      NOT NULL DEFAULT false,
  CONSTRAINT users_pkey             PRIMARY KEY (id),
  CONSTRAINT users_current_session_fkey FOREIGN KEY (current_session)
    REFERENCES public.sessions(id),
  CONSTRAINT users_id_fkey          FOREIGN KEY (id)
    REFERENCES auth.users(id)
);

COMMENT ON COLUMN public.users.music_provider   IS 'User''s music streaming service: apple, spotify, or none';
COMMENT ON COLUMN public.users.spotify_refresh_token IS 'Encrypted Spotify refresh token for OAuth';
COMMENT ON COLUMN public.users.storefront       IS 'Apple Music storefront/region code (e.g., us, gb, ca)';
COMMENT ON COLUMN public.users.is_anonymous     IS 'True for App Clip guests who signed in via signInAnonymously()';

CREATE TABLE public.sessions (
  id            uuid        NOT NULL DEFAULT gen_random_uuid(),
  join_code     text        NOT NULL UNIQUE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  host_id       uuid        NOT NULL,
  current_song  uuid,
  host_provider varchar(20) NOT NULL DEFAULT 'spotify'
                  CHECK (host_provider IN ('apple', 'spotify')),
  CONSTRAINT sessions_pkey             PRIMARY KEY (id),
  CONSTRAINT sessions_host_id_fkey     FOREIGN KEY (host_id)
    REFERENCES public.users(id),
  CONSTRAINT sessions_current_song_fkey FOREIGN KEY (current_song)
    REFERENCES public.queued_songs(id)
);

COMMENT ON COLUMN public.sessions.host_provider IS 'Host''s music provider for this session (apple or spotify)';

CREATE TABLE public.songs (
  external_id      text        NOT NULL,
  name             text        NOT NULL,
  artist           text        NOT NULL,
  album            text        NOT NULL,
  "durationMSs"   bigint      NOT NULL,
  image_url        text        NOT NULL,
  isrc_identifier  text        NOT NULL,
  source           varchar(20) NOT NULL DEFAULT 'spotify',
  CONSTRAINT songs_pkey PRIMARY KEY (external_id)
);

CREATE TABLE public.queued_songs (
  id              uuid                    NOT NULL DEFAULT gen_random_uuid(),
  session_id      uuid                    NOT NULL,
  added_by_id     uuid                    NOT NULL,
  status          public.queued_song_status NOT NULL DEFAULT 'queued',
  song_external_id text                   NOT NULL,
  added_at        timestamptz             NOT NULL DEFAULT now(),
  CONSTRAINT queued_songs_pkey              PRIMARY KEY (id),
  CONSTRAINT queued_songs_session_id_fkey   FOREIGN KEY (session_id)
    REFERENCES public.sessions(id),
  CONSTRAINT queued_songs_added_by_id_fkey  FOREIGN KEY (added_by_id)
    REFERENCES public.users(id),
  CONSTRAINT queued_songs_song_external_id_fkey FOREIGN KEY (song_external_id)
    REFERENCES public.songs(external_id)
);

CREATE TABLE public.votes (
  id              bigint  GENERATED ALWAYS AS IDENTITY NOT NULL,
  queued_song_id  uuid    NOT NULL,
  user_id         uuid    NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  vote_value      integer NOT NULL CHECK (vote_value = 1 OR vote_value = -1),
  CONSTRAINT votes_pkey                 PRIMARY KEY (id),
  CONSTRAINT votes_queued_song_id_fkey  FOREIGN KEY (queued_song_id)
    REFERENCES public.queued_songs(id),
  CONSTRAINT votes_user_id_fkey         FOREIGN KEY (user_id)
    REFERENCES public.users(id)
);

-- ─── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_users_is_anonymous ON public.users (is_anonymous);

-- ─── Auth Trigger ─────────────────────────────────────────────────────────────
-- Creates a public.users profile whenever a new auth.users row is inserted
-- (covers email/password, OAuth, and signInAnonymously).
-- Copies is_anonymous so the profile is correct from creation with no race window.

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
