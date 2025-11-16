-- WARNING: This schema is for context only and may require reordering/adjustments before execution.
-- Table order and constraints may not be valid for execution as-is.

CREATE TABLE public.queued_songs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  added_by_id uuid NOT NULL,
  status USER-DEFINED NOT NULL,
  song_spotify_id text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT queued_songs_pkey PRIMARY KEY (id),
  CONSTRAINT queued_songs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT queued_songs_added_by_id_fkey FOREIGN KEY (added_by_id) REFERENCES public.users(id),
  CONSTRAINT queued_songs_song_spotify_id_fkey FOREIGN KEY (song_spotify_id) REFERENCES public.songs(spotify_id)
);

CREATE TABLE public.sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  join_code text NOT NULL UNIQUE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  host_id uuid NOT NULL,
  current_song uuid,
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_host_id_fkey FOREIGN KEY (host_id) REFERENCES public.users(id),
  CONSTRAINT sessions_current_song_fkey FOREIGN KEY (current_song) REFERENCES public.queued_songs(id)
);

CREATE TABLE public.songs (
  spotify_id text NOT NULL,
  name text NOT NULL,
  artist text NOT NULL,
  album text NOT NULL,
  durationMSs bigint NOT NULL,
  image_url text NOT NULL,
  isrc_identifier text NOT NULL,
  CONSTRAINT songs_pkey PRIMARY KEY (spotify_id)
);

CREATE TABLE public.users (
  id uuid NOT NULL,
  username text UNIQUE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  current_session uuid,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_current_session_fkey FOREIGN KEY (current_session) REFERENCES public.sessions(id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

CREATE TABLE public.votes (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  queued_song_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  vote_value integer NOT NULL CHECK (vote_value = 1 OR vote_value = '-1'::integer),
  CONSTRAINT votes_pkey PRIMARY KEY (id),
  CONSTRAINT votes_queued_song_id_fkey FOREIGN KEY (queued_song_id) REFERENCES public.queued_songs(id),
  CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);


