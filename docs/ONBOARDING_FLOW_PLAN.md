# QueueIT Sign-Up Onboarding & Music Provider Flow

**Decisions finalized:** March 2026  
**Scope:** Auth → profile setup (username, music provider) → full access. Per-session host provider. Search and conflict resolution by provider.

---

## 1. Onboarding Flow (Sign-Up to Full Access)

```
Auth (email / Google / Apple)
         │
         ▼
Trigger: INSERT public.users (id)
         │
         ▼
ProfileSetupView (post-auth, required)
         ├── Username (required)
         └── Music provider: Apple | Spotify | None
         │
         ├── Apple   → MusicKit.requestAccess()
         ├── Spotify → OAuth flow, store token
         └── None    → skip
         │
         ▼
WelcomeView (Create / Join)
         │
         ▼
Full access
```

### 1.1 Profile Setup Rules


| Field              | Required | Notes                                 |
| ------------------ | -------- | ------------------------------------- |
| **Username**       | Yes      | "Added by X", "Hosted by X" — no skip |
| **Music provider** | Yes      | Apple, Spotify, or None               |


### 1.2 Music Provider Choices


| Choice          | Auth Step                            | Can Host? | Search Source             |
| --------------- | ------------------------------------ | --------- | ------------------------- |
| **Apple Music** | `MusicKit.requestAccess()`           | Yes       | MusicKit (Apple catalog)  |
| **Spotify**     | OAuth, store `spotify_refresh_token` | Yes       | Backend (Spotify catalog) |
| **None**        | Skip                                 | No        | Backend (Spotify catalog) |


### 1.3 None + Create Session

If user chose **None** and taps **Create Session**:

- Block with: **"You need a music provider to host. Connect Apple Music or Spotify?"**
- CTA: reopen profile/settings or provider picker to connect a provider.

---

## 2. Search by User Provider

Each user searches using their chosen provider. No mixed catalogs per user.


| User provider   | Search API                 | Catalog |
| --------------- | -------------------------- | ------- |
| **None**        | Backend `/songs/search`    | Spotify |
| **Apple Music** | MusicKit `searchCatalog()` | Apple   |
| **Spotify**     | Backend `/songs/search`    | Spotify |


- **None** and **Spotify** users both use backend Spotify search.
- **Spotify** users also have a connected account for playback when hosting.

---

## 3. Session-Level Host Provider

Each session has a **host provider** (Apple or Spotify) set when the host creates it.


| Session field   | Type                  | Set when                                       |
| --------------- | --------------------- | ---------------------------------------------- |
| `host_provider` | `'apple' | 'spotify'` | Host creates session (from their own provider) |


- No mixed host catalogs per session.
- Host creates session → selects/confirms provider → session stores `host_provider`.
- Guests add songs regardless of their own provider; matching is done against host’s catalog.

---

## 4. Conflict Resolution: Precedence to Host

Rule: **Host’s catalog is the source of truth.**

When a user adds a song:

1. Song comes from their search (Spotify or Apple catalog).
2. Before adding to queue: **resolve song to host’s catalog** (ISRC, artist+title, etc.).
3. If no match: reject with a clear message.
4. If match found: add to queue with host’s catalog ID.

### 4.1 Rejection Message

> "This song isn't available on [host's provider]. Try another."

### 4.2 When to Validate

- **At add time** (preferred): Validate before inserting into `queued_songs`.
- Gives immediate feedback and avoids unplayable items.

---

## 5. Schema Changes

### 5.1 Users Table

```sql
-- Add to public.users
music_provider VARCHAR(20) NOT NULL DEFAULT 'none' 
  CHECK (music_provider IN ('apple', 'spotify', 'none'));
spotify_refresh_token TEXT;  -- encrypted at rest, for Spotify host playback
```

- `username` — required after onboarding (enforce in app; optional in DB for migration).
- `spotify_refresh_token` — only for users who chose Spotify and completed OAuth.

### 5.2 Sessions Table

```sql
-- Add to public.sessions
host_provider VARCHAR(20) NOT NULL 
  CHECK (host_provider IN ('apple', 'spotify'));
```

- Set when host creates session.
- Used for add validation and playback.

### 5.3 Auth Trigger (unchanged)

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, music_provider)
  VALUES (NEW.id, 'none')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 6. End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ONBOARDING & SESSION FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

  Auth (Supabase)
  ├── email/password
  ├── magic link
  ├── Google
  └── Apple
           │
           ▼
  Trigger: public.users (id, music_provider='none')
           │
           ▼
  ProfileSetupView
  ├── Username ──────────────────────────────► UPDATE users SET username
  └── Music provider (Apple | Spotify | None)
       ├── Apple  → requestAccess() ─────────► UPDATE users SET music_provider='apple'
       ├── Spotify → OAuth ──────────────────► UPDATE users, store spotify_refresh_token
       └── None   ───────────────────────────► UPDATE users SET music_provider='none'
           │
           ▼
  WelcomeView (Create / Join)
           │
     ┌─────┴─────┐
     ▼           ▼
  Create      Join
  Session     Session
     │           │
     ▼           ▼
  If None:    Join any session
  BLOCK       Add songs (search via user's provider)
  "Need provider"
     │
     If Apple/Spotify:
     Set host_provider on session
     │
     ▼
  SessionView
  Host plays via host_provider
  Add song → validate against host_provider → add or reject
```

---

## 7. Search Paths (Implementation)


| User provider | iOS                                 | Backend                            |
| ------------- | ----------------------------------- | ---------------------------------- |
| **None**      | Call `POST /songs/search` (Spotify) | Spotify API (client credentials)   |
| **Apple**     | `MusicManager.searchCatalog()`      | —                                  |
| **Spotify**   | Call `POST /songs/search` (Spotify) | Spotify API (client or user token) |


- Backend needs a `GET` or `POST /songs/search` (or equivalent) that queries Spotify catalog.
- Songs table stores `external_id` (platform ID) and `source` (`apple` / `spotify`).
- For add validation: backend resolves requested song to host’s catalog and returns host’s `external_id` or a clear “no match” error.

---

## 8. Edge Cases


| Scenario                          | Handling                                                              |
| --------------------------------- | --------------------------------------------------------------------- |
| None + Create Session             | Block with "You need a music provider to host" and CTA to connect     |
| None + Add song (guest)           | Allow — search via backend Spotify; validate against host’s catalog   |
| Song not in host’s catalog        | Reject at add time with clear message                                 |
| Host changes provider mid-session | Not supported — provider fixed at session create                      |
| MusicKit denied                   | Show "Apple Music access is needed. Enable in Settings."              |
| Spotify OAuth failed              | Show error; allow retry; keep `music_provider = 'none'` until success |
| New user, no trigger              | `ensureUser` endpoint or middleware creates `public.users` row        |


---

## 9. Implementation Checklist

### Onboarding

- Trigger creates `public.users` with `music_provider = 'none'`
- ProfileSetupView after auth (username + music provider)
- Apple: call `MusicManager.requestAccess()` before allowing Continue
- Spotify: OAuth flow, store token, then continue
- None: skip auth, allow continue
- Block Create Session when `music_provider = 'none'`

### Search

- Backend `GET/POST /songs/search` (Spotify catalog)
- iOS: None/Spotify users → backend search; Apple users → MusicKit
- Add song: send metadata + `session_id`; backend validates against `host_provider`

### Session

- Add `host_provider` to sessions; set on create from host’s `music_provider`
- Add validation in add-song: resolve to host catalog, reject if no match

### Schema

- `users.music_provider`, `users.spotify_refresh_token`
- `sessions.host_provider`

---

*Plan finalized March 2026. No mixed host catalogs; precedence to host for conflict resolution.*