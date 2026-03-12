# Onboarding Flow — Implementation Summary

**Completed:** March 2026  
**Plan:** [onboarding_flow_implementation_10b2a9a2.plan.md](./onboarding_flow_implementation_10b2a9a2.plan.md)  
**Spec:** [../../ONBOARDING_FLOW_PLAN.md](../../ONBOARDING_FLOW_PLAN.md)

---

## Overview

The onboarding flow is implemented end-to-end: **Auth → Profile Setup (username + music provider) → WelcomeView**. Spotify OAuth is stubbed; Apple Music and "None (Guest)" are fully supported.

---

## What Was Implemented

### 1. Database (Supabase)

**Migration:** `supabase/migrations/20260311_add_onboarding_fields.sql`

| Table   | Change                                                                 |
|---------|------------------------------------------------------------------------|
| `users` | Added `music_provider` (apple/spotify/none), `spotify_refresh_token`, `storefront` |
| `sessions` | Added `host_provider` (apple/spotify)                              |

**Auth trigger:**
- New users get a `public.users` row with `music_provider = 'none'`.

**RLS (manual step):**
- Added `users_update_self` policy so users can PATCH their own profile.

### 2. Backend (QueueITbackend)

**Config:** `app/core/config.py`
- Apple Music env vars: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_PATH`, `APPLE_MEDIA_ID`

**Services:**
- `app/services/apple_music_service.py` — JWT for Apple Music API, ISRC search, metadata search
- `app/services/song_matching_service.py` — Resolve Spotify → Apple Music via ISRC, fallback to fuzzy match (±3s duration)

**API endpoints:**
- `GET /api/v1/users/me` — Get current user profile
- `PATCH /api/v1/users/me` — Update username, music_provider, storefront

**Session logic:**
- `session_service.py` — Validates host has `music_provider` (not `none`), sets `host_provider` on create
- `queue_service.py` — Add-song validates against host catalog (Spotify → Apple Music resolution)

### 3. iOS (QueueIT)

**Models:**
- `User.swift` — Added `musicProvider`, `storefront`
- `Session.swift` — Added `hostProvider` to `SessionBase`

**Views:**
- `ProfileSetupView.swift` — Username (required), music provider (Apple / Spotify / None), Spotify “Coming Soon” stub
- `RootView.swift` — Shows ProfileSetupView when `needsProfileSetup` is true

**Services:**
- `AuthService.swift` — `needsProfileSetup`, `updateProfile()`, profile load from backend
- `QueueAPIService.swift` — Profile GET/PATCH calls

**Validation:**
- `CreateSessionView.swift` — Blocks users with `music_provider = 'none'` from creating a session (shows “connect provider” alert)

---

## Flow

```
Auth (Supabase: email/Google/Apple)
         │
         ▼
   ProfileSetupView
   ├── Username (required, 3–30 chars)
   └── Music provider
       ├── Apple   → MusicKit.requestAccess() → storefront detection → continue
       ├── Spotify → “Coming Soon” alert (stubbed)
       └── None    → continue (guest only)
         │
         ▼
   WelcomeView
   ├── Create Session (blocked if provider = none)
   └── Join Session (allowed for all)
```

---

## Music Provider Behavior

| Provider   | Can host? | Search source     | Notes                    |
|-----------|-----------|-------------------|--------------------------|
| Apple     | Yes       | MusicKit (Apple)  | Full flow                |
| Spotify   | Yes (stub)| Backend Spotify   | Button shows “Coming Soon” |
| None      | No        | Backend Spotify   | Guest only; cannot create session |

---

## Song Matching (Backend)

When a guest (Spotify/None user) adds a song to an Apple Music host’s session:

1. **ISRC match** — Use Spotify track metadata → Apple Music `filter[isrc]` query
2. **Fuzzy fallback** — If no ISRC match, search by artist+title, require duration within ±3s
3. **Error** — 422 if no match: “This track isn't available on the Host's Apple Music.”

---

## Manual Steps After Deployment

1. Run migration: execute `supabase/migrations/20260311_add_onboarding_fields.sql` (e.g. via Supabase SQL Editor).
2. Backfill existing users: `INSERT INTO public.users (id, music_provider, storefront) SELECT id, 'none', 'us' FROM auth.users ON CONFLICT (id) DO NOTHING;`
3. Add RLS policy:  
   `CREATE POLICY users_update_self ON public.users FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());`

---

## Files Touched

| Layer   | Files |
|---------|-------|
| DB      | `supabase/migrations/20260311_add_onboarding_fields.sql`, `supabase/schema.sql` |
| Backend | `config.py`, `users.py`, `router.py`, `apple_music_service.py`, `song_matching_service.py`, `session_service.py`, `session_repo.py`, `queue_service.py`, `user_repo.py`, `user.py` (schemas), `session.py` (schemas) |
| iOS     | `User.swift`, `Session.swift`, `ProfileSetupView.swift`, `RootView.swift`, `CreateSessionView.swift`, `AuthService.swift`, `QueueAPIService.swift` |

---

## Bug Fixes During Implementation

1. **404 on PATCH /users/me** — Missing `users_update_self` RLS policy; existing users not backfilled into `public.users`.
2. **Guest stuck on Welcome** — `requiresProfileSetup` was treating `provider == "none"` as still needing setup; changed so `provider` set to any value (apple/spotify/none) counts as completed.
