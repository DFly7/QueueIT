-- QueueIT Database Schema
-- This file reflects the current live schema after all migrations have been applied.
-- Last updated: 2026-03-15
--
-- Migration history (run in order):
--   20260311_add_onboarding_fields.sql      – music_provider, storefront, host_provider, trigger
--   20260314_add_is_anonymous_to_users.sql  – is_anonymous column + backfill
--   20260314_anonymous_user_rls.sql         – INSERT/UPDATE/SELECT/DELETE policies for anon users
--   20260314_fix_trigger_is_anonymous.sql   – trigger now copies is_anonymous from auth.users
--   20260315_queue_tier_sorting.sql         – last_entered_tier_at, entered_tier_by_gain + votes trigger
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
  id                    uuid                      NOT NULL DEFAULT gen_random_uuid(),
  session_id            uuid                      NOT NULL,
  added_by_id           uuid                      NOT NULL,
  status                public.queued_song_status NOT NULL DEFAULT 'queued',
  song_external_id      text                      NOT NULL,
  added_at              timestamptz               NOT NULL DEFAULT now(),
  last_entered_tier_at  timestamptz               NOT NULL DEFAULT now(),
  entered_tier_by_gain  boolean                   NOT NULL DEFAULT true,
  CONSTRAINT queued_songs_pkey              PRIMARY KEY (id),
  CONSTRAINT queued_songs_session_id_fkey   FOREIGN KEY (session_id)
    REFERENCES public.sessions(id),
  CONSTRAINT queued_songs_added_by_id_fkey  FOREIGN KEY (added_by_id)
    REFERENCES public.users(id),
  CONSTRAINT queued_songs_song_external_id_fkey FOREIGN KEY (song_external_id)
    REFERENCES public.songs(external_id)
);

COMMENT ON COLUMN public.queued_songs.last_entered_tier_at IS
  'When the song last moved to its current vote count. Updated by tr_queue_tier_sorting trigger.';
COMMENT ON COLUMN public.queued_songs.entered_tier_by_gain IS
  'True = entered tier by gaining a vote (sorts bottom); False = by losing (sorts top).';

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

-- ─── Queue Tier Sorting Trigger ───────────────────────────────────────────────
-- Fires after any INSERT/UPDATE/DELETE on votes.
-- Keeps last_entered_tier_at and entered_tier_by_gain on queued_songs in sync.

CREATE OR REPLACE FUNCTION public.update_queue_tier_metadata()
RETURNS TRIGGER AS $$
DECLARE
  v_queued_song_id uuid;
  v_new_total      integer;
  v_old_total      integer;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_queued_song_id := OLD.queued_song_id;
  ELSE
    v_queued_song_id := NEW.queued_song_id;
  END IF;

  SELECT COALESCE(SUM(vote_value), 0)
    INTO v_new_total
    FROM public.votes
   WHERE queued_song_id = v_queued_song_id;

  IF TG_OP = 'INSERT' THEN
    v_old_total := v_new_total - NEW.vote_value;
  ELSIF TG_OP = 'UPDATE' THEN
    v_old_total := v_new_total - NEW.vote_value + OLD.vote_value;
  ELSE
    v_old_total := v_new_total + OLD.vote_value;
  END IF;

  IF v_new_total <> v_old_total THEN
    UPDATE public.queued_songs
       SET last_entered_tier_at = now(),
           entered_tier_by_gain = (v_new_total > v_old_total)
     WHERE id = v_queued_song_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_queue_tier_sorting ON public.votes;
CREATE TRIGGER tr_queue_tier_sorting
  AFTER INSERT OR UPDATE OR DELETE ON public.votes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_queue_tier_metadata();

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
