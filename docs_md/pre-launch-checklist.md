# Pre–TestFlight & App Store Pitfall Checklist

Pitfalls to fix before moving to TestFlight and App Store. Tick off as you go.

---

## 🔴 Critical (Ship Blockers)

### Backend URL

- [ ] Deploy backend to a stable production URL (Fly.io, Render, Railway, etc.)
- [ ] Set production backend URL in `Config-Release.xcconfig`
- [x] Both main app and App Clip read from APIConfig (xcconfig → Info.plist)

### Railway Deployment — Apple Music Private Key

The `.p8` key cannot be committed to git or baked into a Docker image. Use the base64 pattern:

1. **Encode the key locally:**
   ```bash
   base64 -i QueueITbackend/certs/AuthKey_4H44D28726.p8 | pbcopy
   ```
2. **Add Railway variables** (Service → Variables):
   | Variable | Value |
   |---|---|
   | `APPLE_PRIVATE_KEY_BASE64` | *(paste from clipboard)* |
   | `APPLE_TEAM_ID` | `<your-team-id>` |
   | `APPLE_KEY_ID` | `<your-key-id>` |
   | `APPLE_MEDIA_ID` | `<your-media-id>` |
3. **Do NOT set `APPLE_PRIVATE_KEY_PATH`** in Railway — the base64 var takes priority automatically.
4. **To rotate the key:** update only the `APPLE_PRIVATE_KEY_BASE64` variable and redeploy. No code changes needed.

- [ ] `APPLE_PRIVATE_KEY_BASE64` set in Railway variables
- [ ] `certs/` confirmed in `.gitignore` (already done)

### Invite / App Clip

- [x] Fix InviteView share link: updated to `https://queueitapp.com/join?code=<join_code>` (Universal Link)
- [x] Verify QR codes and share links open the App Clip correctly

### Security

- [ ] Rotate Supabase anon key in Supabase dashboard (current key is in git history)
- [x] Create `Config-Debug.xcconfig` and `Config-Release.xcconfig` (do not add to Git)
- [x] Add `BackendURL`, `SupabaseURL`, `SupabaseAnonKey` to Info.plist as `$(VAR_NAME)` references
- [x] **Assign configurations in Xcode**: Project → Info → Configurations: Debug → Config-Debug, Release → Config-Release for each target
- [x] Add `*.xcconfig` to `.gitignore` (keep `Config.example.xcconfig` as template)
- [x] Main app and App Clip read from APIConfig (Info.plist)

### URL Scheme & Deep Links

- [x] Fix URL scheme mismatch: either add `queueit` as second scheme, or update `parseJoinCode` to accept `com.queueit.app`
- [x] Fix Info.plist malformed `CFBundleURLSchemes` string (remove line break inside `<string>`)
- [x] Test magic link authentication flow end-to-end
- [x] Test custom scheme join links (`queueit://join?code=X` or `com.queueit.app://join?code=X`)

---

## 🟠 High Priority

### Apple Music Rate Limiting

- [ ] Add retry logic with exponential backoff for 429 in `extract_apple_music_track_data` (song_matching_service.py)
- [ ] Add retry logic for 429 in `search_by_isrc` and `search_by_metadata` (apple_music_service.py)
- [ ] Only retry on 429, not other HTTP errors
- [ ] Log retry attempts

### Configuration

- [x] APIConfig reads from `Bundle.main.infoDictionary` (BackendURL, SupabaseURL, SupabaseAnonKey)
- [x] Build configuration (Debug/Release) selects Config-Debug or Config-Release (assign in Xcode)
- [x] Both main app and App Clip use same config source
- [ ] Update all preview mocks to use mock services instead of localhost

### Universal Links

- [x] Add Associated Domains capability: `applinks:queueitapp.com` (main app), `appclips:queueitapp.com` (App Clip)
- [x] Host `apple-app-site-association` file on your domain (GitHub Pages at `pages/`)
- [x] Test Universal Link flow (`https://queueitapp.com/join?code=X`)

### Force Unwraps & Crash Risks

- [x] Backend URL: use APIConfig (fail-fast on invalid config; satisfies force-unwrap concern)
- [x] Replace `randomElement()!` in `AppClipGuestName.swift` with safe fallback
- [x] Replace `URLComponents(...)!` in `QueueAPIService.swift` with safe unwrapping
- [x] Audit remaining `!` and `fatalError` across codebase
- [x] Add proper error handling for edge cases

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

- [x] AuthService uses `KeychainLocalStorage()` (Supabase SDK; encrypted at rest)
- [x] Never use UserDefaults for JWTs (plain-text; use Keychain)
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
- [x] No secrets in source code (keys in xcconfig, gitignored)
- [x] Invite share links open App Clip correctly
- [ ] Magic link and OAuth auth flows work
- [x] Join-by-link (scheme + Universal Link) works
- [ ] Privacy policy URL live
- [ ] Support URL configured
- [ ] App icons complete
- [ ] Tested on physical device (not just simulator)
- [ ] No critical force unwraps in hot paths
- [ ] Apple Music 429 handling in place

---

## 📎 Quick Reference

| Item                        | File(s)                                                                             |
| --------------------------- | ----------------------------------------------------------------------------------- |
| Supabase keys / Backend URL | `Config-Release.xcconfig`, `Config-Debug.xcconfig`, `Info.plist`, `APIConfig.swift` |
| Auth token storage          | `AuthService.swift` (KeychainLocalStorage in SupabaseClientOptions)                 |
| Invite URL                  | `InviteView.swift`                                                                  |
| URL scheme                  | `Info.plist`, `parseJoinCode` in `QueueITApp.swift`, `QueueITClipApp.swift`         |
| Apple Music retry           | `song_matching_service.py`, `apple_music_service.py`                                |
| RLS policies                | `supabase/rls_policies.sql`, `supabase/migrations/`                                 |

### Where to put what

| Data               | Storage                             | Security           |
| ------------------ | ----------------------------------- | ------------------ |
| Backend URL        | .xcconfig → Info.plist              | Low (easy to swap) |
| Supabase Anon Key  | .xcconfig → Info.plist              | Medium             |
| User JWT / Session | Keychain (via KeychainLocalStorage) | High               |

---

_Last updated: March 2026_
