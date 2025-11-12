## QueueUp Shipping Plan (MVP to App Store)

### Vision

Ship a social, shared music queue where groups create/join sessions, search songs, vote, and see a live-updating queue. Host can manage playback/skip.

### Current Status (Today)

- Backend (FastAPI + Supabase)
  - Implemented: base app, CORS, custom OpenAPI with BearerAuth, Supabase JWT verification via JWKS, Spotify search endpoint with typed response, Spotify client credentials flow with token caching.
  - Scaffolds/todo: sessions endpoints (create/join/current/leave/control) mostly stubs; songs add/vote mostly stubs; no real-time; no RLS policy docs; no tests; no ENV.example; verify_jwt not enforced on the router; deployment not configured.
- iOS (SwiftUI)
  - Implemented: simple search UI that calls backend `/api/v1/spotify/search` and displays results with images.
  - Scaffolds/todo: no auth, no create/join session, no queue/voting UI, no WebSockets, no playback control, no environments/config, no TestFlight setup.
- Infra
  - Local dev instructions present. No Dockerfile/CI. Requirements include both `dotenv` and `python-dotenv` (remove `dotenv`). No deployment config.

### MVP Scope (to submit)

- Auth: Sign in (Supabase email magic link) to obtain JWT for protected endpoints. Avoid third-party-only login requirement by including Email (can add Sign in with Apple later).
- Sessions: create/join/leave/current, host lock, skip vote, now playing metadata (no in-app playback in MVP).
- Queue/Voting: add track from Spotify search, upvote/downvote, automatic ordering, skip if >50% of active members vote.
- Real-time: live updates for queue/votes/now playing via WebSockets (FastAPI) or Supabase Realtime. Prefer FastAPI WS for app control; can mirror to Supabase later.
- iOS UI: onboarding/login, session create/join (QR + code), search and add, queue with votes, now playing, skip vote bar.
- Deployment: single FastAPI instance (Fly.io/Render), HTTPS, CORS. Environment variables configured.

### What’s Needed to Reach MVP

- Backend
  - Implement sessions: POST /sessions/create, POST /sessions/join, GET /sessions/current, POST /sessions/leave, PATCH /sessions/control_session.
  - Implement queue/votes: POST /songs/add, POST /songs/{id}/vote; compute sort by votes desc then added_at asc; skip when threshold met, advance queue, reset votes.
  - Real-time: WS channel: `ws://.../api/v1/sessions/{id}/realtime` broadcasting queue/vote changes and now playing.
  - Apply verify_jwt to /api/v1 routes; add error handling/logging; provide `ENV.example`.
  - Data model (Supabase): tables `sessions`, `session_members`, `queued_songs`, `votes`; RLS policies for row-level access by session membership.
- iOS
  - Add auth flow (Supabase Swift): email OTP or magic link; store session securely.
  - Session screens: create (shows join code + QR), join (enter code/scan QR), now playing + queue list + vote buttons, add track from search.
  - WebSocket client for real-time updates.
  - Config: environment switching, base URL, error toasts, loading states.
  - App Store assets/metadata.
- Operations
  - Deploy backend (Fly.io/Render) with env vars, domain, HTTPS.
  - Basic E2E tests for search, create/join, add/vote.
  - TestFlight build and internal testing.

### Proposed Timeline (aggressive, 7–10 days)

- Day 1–2: Backend MVP
  - Define Supabase schema + RLS (SQL scripts).
  - Implement sessions endpoints with verify_jwt enforced.
  - Implement add/vote logic + deterministic ordering.
  - Add WS channel and events: `queue.updated`, `votes.updated`, `now_playing.updated`.
  - Add ENV.example, clean requirements (remove `dotenv`), structured logging.
- Day 3–4: iOS MVP
  - Integrate Supabase Auth (email login).
  - Create/Join flows (code + QR), session state, search → add.
  - Queue UI with voting and optimistic updates.
  - WS integration for live updates.
- Day 5: Deployment and E2E
  - Deploy backend to Fly.io (or Render). Configure CORS, HTTPS.
  - Point iOS to production URL for Release config.
  - E2E manual test run; fix critical bugs.
- Day 6: Polish and App Review Prep
  - Empty state, error copy, loading polish, haptics.
  - App icons, screenshots, privacy policy, support URL, description.
  - Prepare TestFlight build; internal testers validate.
- Day 7–10: Buffer
  - Address review feedback, crash fixes, minor UX tweaks.

### Immediate Next Actions (Today/Tomorrow)

- Backend
  - Enforce auth on `/api/v1` routes; add `ENV.example`.
  - Ship sessions and queue/votes CRUD + sorting; add WS broadcasting.
  - Write minimal tests for endpoints and WS broadcast on mutation.
- Supabase
  - Create tables and RLS policies for sessions/members/queued_songs/votes; export SQL into `supabase/` folder.
- iOS
  - Add Supabase Swift auth; session create/join screens; queue list and vote.
  - Hook up search → add; integrate WS for updates.

### App Store Checklist

- Apple Developer account, bundle ID, App Icons and Launch Storyboard.
- Privacy policy URL, support URL, marketing copy, screenshots.
- Sign in method: Email (ok) or if third-party used, add “Sign in with Apple”.
- Build with Release config, archive, upload to TestFlight, fill App Store Connect metadata.

### Risks and Mitigations

- Spotify playback SDK approval/time: Defer in-app playback to v2; MVP focuses on queue and control UX.
- Real-time complexity: Start with FastAPI WS; if scale needs it, evaluate Supabase Realtime relay.
- App Review timing: Submit minimal but compliant feature set; clear privacy copy; use email auth to avoid Apple sign-in requirement.

### Definition of Done (MVP)

- Users can auth, create/join a session, search/add tracks, vote, see live queue and now playing, and collectively skip.
- Backend deployed and stable; iOS build available on TestFlight; App Store metadata complete and ready for review.
