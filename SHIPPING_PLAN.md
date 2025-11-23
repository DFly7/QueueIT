# QueueUp Shipping Plan (MVP to App Store)

**Last Updated:** November 22, 2025  
**Status:** 🔴 CODE COMPLETE BUT NOT PRODUCTION READY  
**Est. Time to Launch:** 10-14 days (after critical fixes)

---

## 📋 Table of Contents

1. [Vision & Scope](#vision)
2. [Code Review Summary](#code-review-summary)
3. [Critical Issues (Ship Blockers)](#critical-issues-ship-blockers)
4. [Current Status](#current-status)
5. [Revised Timeline](#revised-timeline)
6. [Updated Action Plan](#updated-action-plan)
7. [App Store Checklist](#app-store-checklist)
8. [Definition of Done](#definition-of-done)

---

## Vision

Ship a social, shared music queue where groups create/join sessions, search songs, vote, and see a live-updating queue. Host can manage playback/skip.

---

## Code Review Summary

**Three comprehensive reviews completed:**
- ✅ `backend_review.md` - FastAPI + Supabase backend
- ✅ `frontend_review.md` - iOS SwiftUI app
- ✅ `system_review.md` - Full stack integration

### Overall Assessment

**Backend:** ⚠️ NOT PRODUCTION READY  
- Architecture: ✅ Excellent
- Implementation: ⚠️ Incomplete
- Security: ❌ RLS not enforced
- Critical Missing: WebSocket support

**Frontend:** ⚠️ FUNCTIONAL BUT NOT PRODUCTION READY  
- Architecture: ✅ Excellent
- Implementation: ✅ Feature complete
- Security: ❌ Keys exposed, insecure storage
- Critical Missing: Environment config

**Integration:** 🔴 INCOMPLETE - NOT FUNCTIONAL  
- API contracts: ✅ Well defined
- Real-time: ❌ Broken (WebSocket missing)
- Security: ❌ RLS not applied
- Testing: ❌ Zero integration tests

---

## 🔴 CRITICAL ISSUES (Ship Blockers)

**These MUST be fixed before ANY deployment or TestFlight distribution.**

### 1. WebSocket Real-Time Support NOT IMPLEMENTED (Backend)

**Impact:** Core feature completely broken  
**Effort:** 2-3 days  
**Owner:** Backend team

- [ ] Implement `/api/v1/sessions/{id}/realtime` WebSocket endpoint
- [ ] Add ConnectionManager for session-based broadcasting
- [ ] Emit events on mutations: `queue.updated`, `votes.updated`, `now_playing.updated`
- [ ] Handle JWT authentication in WebSocket connection
- [ ] Test with multiple clients

**Without this:** App appears to work but no real-time updates occur. Users must manually refresh.

---

### 2. Missing Critical Dependencies (Backend)

**Impact:** Code won't run  
**Effort:** 15 minutes  
**Owner:** Backend team

Add to `requirements.txt`:
```txt
supabase==2.4.0
postgrest==0.13.2
PyJWT[crypto]==2.8.0
cryptography==41.0.7
```

---

### 3. RLS Policies Not Applied (Security)

**Impact:** CRITICAL SECURITY VULNERABILITY - Any user can access any session  
**Effort:** 1 day (apply + test)  
**Owner:** Backend/DevOps

- [ ] Execute `supabase/rls_policies.sql` on production Supabase
- [ ] Add missing policies (UPDATE users, INSERT sessions, DELETE queued_songs)
- [ ] Test with multiple user accounts to verify enforcement
- [ ] Document RLS testing procedure

**Without this:** Authorization completely bypassed. User A can access User B's session.

---

### 4. Database Schema Incomplete (Backend)

**Impact:** Queued songs table will fail  
**Effort:** 30 minutes  
**Owner:** Backend/DevOps

```sql
-- Add missing ENUM type
CREATE TYPE queue_status AS ENUM ('queued', 'playing', 'played', 'skipped');

-- Update table
ALTER TABLE queued_songs 
  ALTER COLUMN status TYPE queue_status USING status::queue_status,
  ALTER COLUMN status SET DEFAULT 'queued';
```

---

### 5. API Keys Exposed in Source Code (Security)

**Impact:** CRITICAL SECURITY BREACH  
**Effort:** 1 day  
**Owner:** iOS team

- [ ] **IMMEDIATELY** rotate Supabase anon key (already in git history)
- [ ] Remove hardcoded keys from `QueueITApp.swift`
- [ ] Implement Config.plist system with .gitignore
- [ ] Create Config.example.plist for team
- [ ] Document secure configuration process

**Exposed Key:**
```swift
// LINE 17 of QueueITApp.swift - EXPOSED IN GIT
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

### 6. Hardcoded Localhost URLs (iOS)

**Impact:** App won't work on physical devices or TestFlight  
**Effort:** 1 day  
**Owner:** iOS team

- [ ] Create Environment configuration system (dev/staging/prod)
- [ ] Remove hardcoded `http://localhost:8000` from QueueITApp.swift
- [ ] Remove hardcoded URL from SessionCoordinator.swift
- [ ] Add build configuration support
- [ ] Test on physical device

**Current:**
```swift
private let backendURL = URL(string: "http://localhost:8000")! // Simulator only!
```

---

### 7. Insecure Token Storage (iOS)

**Impact:** JWT tokens accessible to malware  
**Effort:** 1 day  
**Owner:** iOS team

- [ ] Implement Keychain-based AuthStorage
- [ ] Replace UserDefaults storage in Supabase SDK
- [ ] Test token persistence after app restart
- [ ] Document secure storage approach

---

### 8. Missing ENV.example File (Backend)

**Impact:** New developers can't set up project  
**Effort:** 15 minutes  
**Owner:** Backend team

Create `QueueITbackend/ENV.example`:
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLIC_ANON_KEY=your-anon-key-here
SPOTIFY_CLIENT_ID=your-spotify-client-id
SPOTIFY_CLIENT_SECRET=your-spotify-client-secret
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
ENVIRONMENT=development
```

---

### 9. Deep Link Configuration Missing (iOS)

**Impact:** Magic link authentication will fail  
**Effort:** 1 hour  
**Owner:** iOS team

- [ ] Add URL scheme to Info.plist: `com.queueit.app`
- [ ] Configure Associated Domains for Universal Links
- [ ] Add `.onOpenURL` handler to QueueITApp.swift
- [ ] Test magic link flow end-to-end

---

### 10. Force Unwrapping Throughout iOS Code

**Impact:** App will crash in production  
**Effort:** 4 hours  
**Owner:** iOS team

- [ ] Audit and remove ~15 force unwraps (`!`)
- [ ] Replace with safe unwrapping or preconditionFailure
- [ ] Add proper error handling
- [ ] Test error scenarios

---

## Current Status (Detailed)

### Backend (FastAPI + Supabase)

**✅ Implemented:**
- Clean architecture (services/repositories/schemas)
- JWT authentication via Supabase JWKS
- All REST endpoints (sessions, songs, voting, search)
- Spotify search with token caching
- Proper RLS-aware Supabase client usage
- Field aliasing for iOS compatibility

**❌ Critical Missing:**
- WebSocket endpoint (real-time broken)
- RLS policies not applied (security breach)
- Missing dependencies in requirements.txt
- ENV.example file
- Database ENUM type
- Rate limiting
- Structured logging
- Health checks for dependencies

**⚠️ Needs Work:**
- Error handling (duplicate join codes)
- Input validation (join code format)
- Transaction handling (multi-step operations)
- Pagination (queue endpoint)

---

### iOS (SwiftUI)

**✅ Implemented:**
- Complete MVVM architecture
- Supabase Auth integration (email/password, magic link, OAuth, Apple)
- All UI screens (welcome, auth, create, join, session, search)
- Beautiful gradient-based design system
- Session management (create/join/leave)
- Song search and add
- Voting UI with animations
- Host controls
- WebSocket service (frontend ready, backend missing)

**❌ Critical Missing:**
- Environment configuration (hardcoded localhost)
- Secure token storage (using UserDefaults)
- Deep link configuration
- Config.plist for API keys
- Force unwrap removal

**⚠️ Needs Work:**
- Error handling UI (banners, retry)
- Loading states (voting, adding songs)
- Image caching
- Accessibility (VoiceOver, Dynamic Type)
- Optimistic UI updates
- Memory leak fixes (WebSocket)
- QR code generation

---

### Integration

**✅ Working:**
- Auth flow (Supabase → JWT → Backend)
- Session creation
- Session joining
- Song addition
- Voting
- Spotify search

**❌ Broken:**
- Real-time updates (WebSocket endpoint missing)
- Authorization (RLS not enforced)

**⚠️ Suboptimal:**
- Vote updates (full refresh instead of event)
- No optimistic updates
- No request tracing
- No error standardization

---

## Revised Timeline

### Previous Estimate: 7-10 days (UNREALISTIC)

**New Estimate: 10-14 working days**

The original plan underestimated:
1. WebSocket implementation complexity
2. Security configuration work
3. Testing and integration verification
4. Production deployment setup

---

## Updated Action Plan

### 🔥 Week 1: Critical Fixes (5 days) - NO EXCEPTIONS

#### Day 1: Backend WebSocket + Dependencies

**Morning (4 hours):**
- [ ] Add missing dependencies to requirements.txt
- [ ] Create ENV.example
- [ ] Fix database schema (ENUM type)
- [ ] Test backend starts without errors

**Afternoon (4 hours):**
- [ ] Implement WebSocket endpoint with ConnectionManager
- [ ] Add JWT verification for WebSocket connections
- [ ] Test with `wscat` or Postman

**Success Criteria:** WebSocket accepts connections and echoes messages

---

#### Day 2: Backend Real-Time Integration

**Morning (4 hours):**
- [ ] Add broadcasting on song add (emit `queue.updated`)
- [ ] Add broadcasting on vote (emit `votes.updated`)
- [ ] Add broadcasting on skip (emit `now_playing.updated`)

**Afternoon (4 hours):**
- [ ] Test multi-client broadcasting
- [ ] Add connection cleanup on disconnect
- [ ] Handle reconnection scenarios

**Success Criteria:** Multiple clients receive real-time updates

---

#### Day 3: Security Lockdown

**Morning (4 hours):**
- [ ] **ROTATE Supabase anon key** (exposed in git)
- [ ] Apply RLS policies on Supabase production
- [ ] Add missing RLS policies (see backend_review.md)
- [ ] Test RLS enforcement with 2 user accounts

**Afternoon (4 hours):**
- [ ] Implement Keychain storage in iOS
- [ ] Remove hardcoded keys from iOS source
- [ ] Create Config.plist system
- [ ] Update documentation

**Success Criteria:** User A cannot access User B's session. Tokens stored securely.

---

#### Day 4: iOS Configuration & WebSocket

**Morning (4 hours):**
- [ ] Create Environment config system (dev/staging/prod)
- [ ] Remove all hardcoded localhost URLs
- [ ] Add build configurations
- [ ] Test backend WebSocket with iOS

**Afternoon (4 hours):**
- [ ] Implement WebSocket error handling & reconnection
- [ ] Add polling fallback
- [ ] Add connection status UI
- [ ] Test on physical device

**Success Criteria:** iOS connects to WebSocket and receives real-time updates

---

#### Day 5: Integration Testing & Bug Fixes

**Morning (4 hours):**
- [ ] Test complete flow: auth → create → join → add → vote
- [ ] Test with 2 users on physical devices
- [ ] Fix any discovered issues
- [ ] Document test results

**Afternoon (4 hours):**
- [ ] Fix force unwraps in iOS
- [ ] Configure deep links (Info.plist, handlers)
- [ ] Test magic link flow
- [ ] Code review and cleanup

**Success Criteria:** End-to-end flow works with real-time updates

---

### 🚀 Week 2: Production Readiness (5 days)

#### Day 6: Backend Production Prep

**Tasks:**
- [ ] Add structured logging (JSON logs)
- [ ] Implement rate limiting (20 req/min per endpoint)
- [ ] Add health check with dependency validation
- [ ] Improve error handling (duplicate codes, validation)
- [ ] Add request IDs for tracing

**Success Criteria:** Backend ready for production deployment

---

## Logging Rollout Plan (New)

### Work Breakdown (Priority Order)

1. **logging:setup** — 1 day — Configure `structlog`, env plumbing, stdout JSON — **Critical** — Owner: `@agent`
2. **logging:request-id** — 0.5 day — Middleware + response header + tests — **Critical** — Owner: `@agent` — Depends on `logging:setup`
3. **logging:access** — 0.5 day — Access middleware + Prometheus metrics — **Critical** — Owner: `@agent` — Depends on `logging:request-id`
4. **logging:exceptions** — 0.5 day — Central handlers + Sentry integration — **Critical** — Owner: `@agent` — Depends on `logging:setup`
5. **logging:db** — 1 day — Slow-query logging & sanitizers — **High** — Owner: `@agent`
6. **logging:background** — 0.5 day — Context propagation helper + docs — **High** — Owner: `@agent`
7. **logging:docs-tests-ci** — 1 day — Pytest coverage, `docs/logging.md`, CI workflow — **High** — Owner: `@agent` — Depends on previous tasks

### Timeline & Dependencies

- **Day 1:** Complete logging config + request-id middleware, land smoke tests.
- **Day 2:** Access logs, Prometheus counters/histograms, exception handler wiring.
- **Day 3:** DB + third-party instrumentation, background task helper.
- **Day 4:** Documentation updates, CI workflow, staging dry-run.

### Rollout / Deployment Plan

1. Deploy to staging with `LOG_LEVEL=INFO`, `LOG_JSON=true`, `ENABLE_PROMETHEUS=true`.
2. Hit `/healthz`, `/metrics`, and authenticated endpoints; confirm log entries in aggregator contain `request_id` and `user_id`.
3. Enable `SENTRY_DSN` in staging, trigger a synthetic error, ensure it appears in Sentry with the same `request_id`.
4. Promote to production during a low-traffic window while monitoring request latency histograms and error counts.

### Rollback Plan

- Toggle `LOG_ENRICHMENT=false` to reduce payload size if volume spikes.
- Set `ENABLE_PROMETHEUS=false` if scraping impacts performance.
- Remove `SENTRY_DSN` to disable error forwarding if noise overwhelms on-call.
- Revert PR `chore(logging): implement structured, request-id aware logging` for full rollback.

### Post-Deploy Checklist

- [ ] Responses include `X-Request-ID` in staging and production.
- [ ] Log aggregation dashboards show `service`, `env`, `request_id`, `user_id`.
- [ ] Prometheus histograms trend within pre-change latency bands.
- [ ] Triggered HTTP 4xx/5xx logs correlate with Sentry events.
- [ ] Background task logs display `background_task_id` and inherit request ids.
- [ ] Runbook updated with troubleshooting steps for logging config.

---

#### Day 7: Backend Deployment

**Tasks:**
- [ ] Deploy to staging (Fly.io or Render)
- [ ] Configure environment variables
- [ ] Setup CORS for iOS app domain
- [ ] Enable HTTPS
- [ ] Test all endpoints against staging

**Success Criteria:** Staging backend fully functional

---

#### Day 8: iOS Polish & Error Handling

**Tasks:**
- [ ] Add error banners and retry logic
- [ ] Implement optimistic UI updates (voting)
- [ ] Add loading states
- [ ] Add image caching (Kingfisher)
- [ ] Configure production backend URL

**Success Criteria:** Smooth user experience with error handling

---

#### Day 9: TestFlight Preparation

**Tasks:**
- [ ] Fix all build warnings
- [ ] Add accessibility labels (VoiceOver)
- [ ] Test on multiple device sizes (iPhone SE, Pro Max, iPad)
- [ ] Create App Store screenshots
- [ ] Write App Store description
- [ ] Privacy policy URL
- [ ] Support URL

**Success Criteria:** App ready for TestFlight distribution

---

#### Day 10: Testing & Launch Prep

**Morning (4 hours):**
- [ ] Deploy backend to production
- [ ] Update iOS with production URLs
- [ ] Create TestFlight build
- [ ] Internal testing with 3-5 users

**Afternoon (4 hours):**
- [ ] Fix critical bugs from testing
- [ ] Add analytics/crash reporting
- [ ] Final security audit
- [ ] Prepare App Store submission

**Success Criteria:** App functional on TestFlight with production backend

---

### 📅 Days 11-14: Buffer & App Review

**Contingency time for:**
- Unexpected bugs
- TestFlight feedback
- App Store review feedback
- Performance issues
- Additional security hardening

---

## Critical Before Launch

**These items MUST be checked before ANY public release:**

### Backend
- [ ] WebSocket endpoint implemented and tested
- [ ] RLS policies applied and verified
- [ ] All dependencies in requirements.txt
- [ ] ENV.example created
- [ ] Database schema complete
- [ ] Rate limiting enabled
- [ ] Structured logging configured
- [ ] Error handling improved
- [ ] Health check validates all services
- [ ] HTTPS enforced
- [ ] CORS restricted to iOS domain

### iOS
- [ ] Environment config system implemented
- [ ] Hardcoded URLs removed
- [ ] Keychain storage implemented
- [ ] API keys secured in Config.plist
- [ ] Config.plist in .gitignore
- [ ] Deep links configured
- [ ] Force unwraps removed
- [ ] Error handling comprehensive
- [ ] Tested on physical devices (not just simulator)
- [ ] Accessibility labels added
- [ ] No console errors or warnings

### Integration
- [ ] End-to-end flow tested with 2+ users
- [ ] Real-time updates working
- [ ] RLS enforcement verified
- [ ] Auth flow complete (sign up, sign in, magic link)
- [ ] Error scenarios tested (network failure, etc.)
- [ ] Performance tested (50+ concurrent users)

### Security
- [ ] Supabase anon key rotated (old key in git history)
- [ ] No secrets in source code
- [ ] RLS policies prevent unauthorized access
- [ ] JWT tokens stored securely
- [ ] HTTPS only in production
- [ ] CORS properly configured

### Operations
- [ ] Backend deployed to production
- [ ] Database migrations applied
- [ ] Monitoring configured
- [ ] Backup/recovery plan documented
- [ ] Incident response plan documented

---

## App Store Checklist

### Pre-Submission
- [ ] Apple Developer account active ($99/year)
- [ ] Bundle ID created: `com.queueit.app`
- [ ] App icons (all required sizes: 20x20 to 1024x1024)
- [ ] Launch screen configured
- [ ] Privacy policy published online (URL ready)
- [ ] Support URL configured
- [ ] App Store screenshots (iPhone: 6.7", 6.5", 5.5"; iPad)
- [ ] App Store description written
- [ ] Keywords researched (max 100 chars)
- [ ] Age rating determined (likely 4+)
- [ ] App category selected (Music or Social Networking)

### Sign In Method
- [ ] Email/Password ✅ (acceptable)
- [ ] Magic Link ✅ (acceptable)
- [ ] Google OAuth ⚠️ (requires Sign In with Apple)
- [ ] Sign In with Apple (implement if using Google)

### Review Requirements
- [ ] Demo account credentials provided
- [ ] All features functional
- [ ] No placeholder content
- [ ] No references to beta/test
- [ ] Proper error messages (user-friendly)
- [ ] Permissions clearly explained (notifications, camera for QR)
- [ ] Works on all supported devices

### Build Configuration
- [ ] Release build configuration created
- [ ] Production backend URLs
- [ ] Proper code signing
- [ ] Archive created
- [ ] Uploaded to App Store Connect
- [ ] TestFlight tested before submission

---

## Risks and Mitigations

### Risk 1: WebSocket Implementation Complexity
**Mitigation:** Start with simple broadcast, optimize later. Fallback to polling.

### Risk 2: RLS Testing Insufficient
**Mitigation:** Dedicated integration test suite with multiple users. Manual verification.

### Risk 3: App Store Rejection
**Mitigation:** Follow guidelines strictly. Email auth instead of third-party only. Clear privacy policy.

### Risk 4: Performance Issues with Scale
**Mitigation:** Test with 50+ concurrent users before launch. Horizontal scaling plan ready.

### Risk 5: Supabase Key Already Exposed
**Mitigation:** Rotate immediately. Monitor usage for abuse. Add rate limiting.

### Risk 6: Schedule Slippage
**Mitigation:** 4-day buffer built in. Daily standups. Weekly milestone reviews.

---

## Definition of Done (MVP)

### Functional Requirements
✅ Users can register/sign in with email  
✅ Users can create a session with custom join code  
✅ Users can join a session by code  
✅ Users can search Spotify tracks  
✅ Users can add tracks to queue  
✅ Users can upvote/downvote tracks  
✅ Queue sorts by votes (desc) then added time (asc)  
✅ Host can skip current track  
✅ Real-time updates for all session members  
✅ Users can leave session  

### Technical Requirements
✅ Backend deployed on HTTPS  
✅ RLS policies enforced  
✅ WebSocket real-time working  
✅ iOS app on TestFlight  
✅ All security issues resolved  
✅ Integration tests passing  
✅ Zero critical bugs  

### Launch Requirements
✅ App Store metadata complete  
✅ Privacy policy published  
✅ Support URL configured  
✅ Internal testing completed (5+ users)  
✅ Crash reporting enabled  
✅ Analytics configured  
✅ Monitoring/alerting setup  

---

## Success Metrics (Post-Launch)

**Week 1:**
- 50+ TestFlight users
- <5% crash rate
- <2% error rate
- Average session duration >10 minutes

**Month 1:**
- 500+ registered users
- 100+ active sessions created
- 1000+ songs added to queues
- 4+ star rating

**Month 3:**
- 5000+ users
- App Store feature consideration
- <1% crash rate
- >50% weekly retention

---

## Resources & Documentation

**Reviews:**
- `backend_review.md` - Complete backend analysis with code examples
- `frontend_review.md` - Complete iOS analysis with fixes
- `system_review.md` - Integration and architecture review

**Code:**
- Backend: `/QueueITbackend`
- iOS: `/QueueIT/QueueIT`
- Database: `/supabase`

**Documentation:**
- API Contracts: `/QueueITbackend/docs/API_CONTRACTS.md`
- Architecture: `/QueueITbackend/docs/ARCHITECTURE.md`

**Deployment:**
- Backend: Fly.io or Render (TBD)
- Database: Supabase (hosted)
- iOS: App Store via TestFlight

---

## Team Communication

**Daily Standup Questions:**
1. What did you complete yesterday?
2. What are you working on today?
3. Any blockers?
4. Any security concerns?

**Weekly Milestone Review:**
- Progress against plan
- Risk assessment
- Timeline adjustment if needed
- Demo of completed features

**Launch Decision Meeting:**
- All critical issues resolved?
- Integration tests passing?
- Security audit clean?
- GO / NO-GO decision

---

## Contact & Support

**Development Team:**
- Backend Lead: [Assign]
- iOS Lead: [Assign]
- DevOps: [Assign]
- QA: [Assign]

**Escalation Path:**
- Critical bugs: Immediately notify team lead
- Security issues: Stop and address immediately
- Timeline risks: Discuss in daily standup

---

**Plan Last Updated:** November 22, 2025  
**Next Review:** After Week 1 completion  
**Status:** 🔴 Action Required - Begin Week 1 Critical Fixes Immediately
