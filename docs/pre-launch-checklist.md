# Pre–TestFlight & App Store Pitfall Checklist

Pitfalls to fix before moving to TestFlight and App Store. Tick off as you go.

---

## 🔴 Critical (Ship Blockers)

### Backend URL
- [ ] Deploy backend to a stable production URL (Fly.io, Render, Railway, etc.)
- [ ] Replace ngrok URL in `QueueITApp.swift` with production backend URL
- [ ] Replace ngrok URL in `QueueITClipApp.swift` with production backend URL
- [ ] Add environment configuration (dev/staging/prod) so URLs aren't hardcoded

### Invite / App Clip
- [ ] Fix InviteView share link: change `com.yourcompany.queueit.Clip` to `DF.QueueIT12.Clip` (or actual App Clip bundle ID)
- [ ] Verify QR codes and share links open the App Clip correctly

### Security
- [ ] Rotate Supabase anon key in Supabase dashboard (current key is in git history)
- [ ] Move Supabase URL and anon key to `Config.plist` or `.xcconfig`
- [ ] Add `Config.plist` to `.gitignore`
- [ ] Create `Config.example.plist` for other developers
- [ ] Update main app to read keys from config
- [ ] Update App Clip to read keys from config

### URL Scheme & Deep Links
- [ ] Fix URL scheme mismatch: either add `queueit` as second scheme, or update `parseJoinCode` to accept `com.queueit.app`
- [ ] Fix Info.plist malformed `CFBundleURLSchemes` string (remove line break inside `<string>`)
- [ ] Test magic link authentication flow end-to-end
- [ ] Test custom scheme join links (`queueit://join?code=X` or `com.queueit.app://join?code=X`)

---

## 🟠 High Priority

### Apple Music Rate Limiting
- [ ] Add retry logic with exponential backoff for 429 in `extract_apple_music_track_data` (song_matching_service.py)
- [ ] Add retry logic for 429 in `search_by_isrc` and `search_by_metadata` (apple_music_service.py)
- [ ] Only retry on 429, not other HTTP errors
- [ ] Log retry attempts

### Configuration
- [ ] Create shared `Environment` enum (dev/staging/prod)
- [ ] Use build configuration to select environment
- [ ] Ensure both main app and App Clip use same config source
- [ ] Update all preview mocks to use mock services instead of localhost

### Universal Links
- [ ] Add Associated Domains capability: `applinks:queueit.app`, `appclips:queueit.app`
- [ ] Host `apple-app-site-association` file on your domain
- [ ] Test Universal Link flow (`https://queueit.app/join?code=X`)

### Force Unwraps & Crash Risks
- [ ] Replace force unwrap in `QueueITApp.swift` backend URL
- [ ] Replace `randomElement()!` in `AppClipGuestName.swift` with safe fallback
- [ ] Replace `URLComponents(...)!` in `QueueAPIService.swift` with safe unwrapping
- [ ] Audit remaining `!` and `fatalError` across codebase
- [ ] Add proper error handling for edge cases

---

## 🟡 Medium Priority

### App Store Metadata
- [ ] Publish privacy policy and have a live URL
- [ ] Set up support page and URL
- [ ] Create App Store screenshots (6.7", 6.5", 5.5" iPhone; iPad if applicable)
- [ ] Write App Store description
- [ ] Research and add keywords (max 100 chars)
- [ ] Determine age rating (likely 4+)
- [ ] Select app category (Music or Social Networking)

### Token Storage
- [ ] Implement Keychain-based `AuthStorage` for Supabase
- [ ] Replace UserDefaults storage with Keychain
- [ ] Test token persistence after app restart

### App Icons
- [ ] Add actual app icons for all required sizes (20px to 1024px)
- [ ] Add App Clip icon if needed
- [ ] Verify no placeholder or missing icons

### Database
- [ ] Confirm `sessions` table has appropriate RLS policy for INSERT (if needed)
- [ ] Verify all migrations applied to production Supabase

### Offline / Error UX
- [ ] Add retry logic for failed API requests
- [ ] Add user-visible error banners or toasts
- [ ] Consider simple offline indicator

---

## 🟢 Lower Priority

### Code Cleanup
- [ ] Remove deprecated `WebSocketService` (RealtimeService is used instead)
- [ ] Fix preview mocks to use mock `QueueAPIService` instead of localhost URLs

### Observability
- [ ] Add analytics (e.g. TelemetryDeck, Firebase)
- [ ] Add crash reporting (e.g. Sentry)
- [ ] Set up monitoring/alerting for backend

### Accessibility
- [ ] Add VoiceOver labels to interactive elements
- [ ] Add accessibility hints where helpful
- [ ] Test with Accessibility Inspector
- [ ] Support Dynamic Type where appropriate

---

## ✅ Definition of Done (Pre-TestFlight)

Before submitting to TestFlight:

- [ ] Backend deployed to stable HTTPS URL
- [ ] Both app targets point to production backend
- [ ] No secrets in source code
- [ ] Invite share links open App Clip correctly
- [ ] Magic link and OAuth auth flows work
- [ ] Join-by-link (scheme + Universal Link) works
- [ ] Privacy policy URL live
- [ ] Support URL configured
- [ ] App icons complete
- [ ] Tested on physical device (not just simulator)
- [ ] No critical force unwraps in hot paths
- [ ] Apple Music 429 handling in place

---

## 📎 Quick Reference

| Item | File(s) |
|------|---------|
| Backend URL | `QueueITApp.swift`, `QueueITClipApp.swift` |
| Invite URL | `InviteView.swift` |
| Supabase keys | `QueueITApp.swift`, `QueueITClipApp.swift` |
| URL scheme | `Info.plist`, `parseJoinCode` in `QueueITApp.swift`, `QueueITClipApp.swift` |
| Apple Music retry | `song_matching_service.py`, `apple_music_service.py` |
| RLS policies | `supabase/rls_policies.sql`, `supabase/migrations/` |

---

*Last updated: March 2026*
