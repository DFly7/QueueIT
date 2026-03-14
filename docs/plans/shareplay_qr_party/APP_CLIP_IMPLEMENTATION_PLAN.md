# QueueIT App Clip – Implementation Plan (2026)

**Created:** March 14, 2026  
**Status:** Planning  
**Scope:** Zero-friction guest entry via QR/link – no full app install required.

---

## Executive Summary

An App Clip lets guests scan a QR code or click a link and **immediately** search + vote without installing the full QueueIT app. This plan maps the 5-step framework to your **actual codebase** – existing targets, services, models, and backend.

### The Magic Moment (Target UX)

1. **Host** taps "Invite Friends" → QR code appears
2. **Guest** scans QR → **App Clip Card** pops up (no App Store)
3. **Guest** taps "Join" → Queue View opens in ~3 seconds
4. **Guest** adds a song → Host's speakers play it (Spotify → Apple resolution already done)

---

## Current Structure Snapshot

| Component | Your Codebase | App Clip Relevance |
|-----------|---------------|-------------------|
| **Main app target** | `QueueIT` | Parent app; shares code with Clip |
| **Networking** | `QueueAPIService` | ✅ Share – all API calls go through it |
| **Models** | `Track`, `Session`, `AddSongRequest` | ✅ Share – add/vote/queue logic |
| **Theme** | `AppTheme` | ✅ Share – keep neon aesthetic |
| **Auth** | `AuthService` (Supabase) | 🔄 Modify – add anonymous path for Clip |
| **Session flow** | `SessionCoordinator` | ✅ Share – join, current session, add song |
| **Search** | `UnifiedSearchView` + `TrackSearchProvider` | ✅ Share – backend Spotify proxy |
| **Host UI** | `HostControlsView`, `CreateSessionView` | ❌ Exclude – App Clip = guest-only |
| **Backend** | FastAPI + Supabase + JWT | 🔄 Backend accepts anonymous JWT |
| **URL handling** | `queueit` scheme for OAuth only | 🔄 Add join URL handling |
| **Domain** | Not configured | 🔴 Need `queueit.app` or similar |
| **QR** | Placeholder in `JoinSessionView` | 🔴 Build; host shows QR |

---

## Step 1: The Split-Target Setup

### 1.1 Create the App Clip Target

In Xcode:
- `File > New > Target` → **App Clip**
- Bundle ID: `com.yourcompany.queueit.Clip` (or `com.queueit.app.Clip`)

### 1.2 Files to Share (File Inspector → Target Membership)

Check **both** main App and App Clip for:

| File / Folder | Purpose |
|---------------|---------|
| `Services/QueueAPIService.swift` | API client |
| `Services/AuthService.swift` | Auth (will add anonymous path) |
| `Services/SessionCoordinator.swift` | Session state, join, add song |
| `Services/TrackSearchProvider.swift` | Search abstraction |
| `Models/Track.swift` | Track model |
| `Models/Session.swift` | Session, `CurrentSessionResponse`, `QueuedSongResponse` |
| `Models/AddSongRequest.swift` | Add-song request |
| `Models/UnifiedTrackSearchViewModel.swift` | Search view model |
| `Theme/AppTheme.swift` | Colors, gradients |
| `Views/Components/NeonBackground.swift` | Background |
| `Views/Components/QueueItemCard.swift` | Queue row |
| `Views/Components/NowPlayingCard.swift` | Now playing row |
| `Extensions/Song+Track.swift` | If used by add flow |

**Exclude from App Clip:**
- `MusicManager.swift` – host-only playback
- `RealtimeService.swift` / `WebSocketService.swift` – optional for Clip; can add later
- `Views/CreateSessionView.swift`, `Views/HostControlsView.swift`
- `Views/WelcomeView.swift`, `Views/AuthView.swift`, `Views/ProfileSetupView.swift`
- SwiftData / `Item.swift` – App Clip is ephemeral, no local DB needed

### 1.3 Keep It Light (50MB / &lt;3s Rule)

- No heavy animations, video, or large images
- Use `NeonBackground` with `showGrid: false` or a simplified variant
- Avoid `RealtimeService` initially – poll `current_session` if needed, or add WebSocket later
- Lazy-load `UnifiedSearchView` only when user taps Add

---

## Step 2: Guest-Only UI

The App Clip has **two screens only**.

### 2.1 Landing Screen (Queue View)

- **Immediately** show current session queue + now playing
- Fetch via `SessionCoordinator` → `apiService.getCurrentSession()` (uses join_code from URL)
- Reuse: `NowPlayingCard`, `QueueItemCard`, `NeonBackground`, queue list layout
- Single action: "Add Song" → opens search overlay
- Leave button → dismiss App Clip

**Data flow:** On launch, App Clip receives `join_code` from URL.  
Call `sessionCoordinator.joinSession(joinCode:)` **before** showing queue if not yet in session.  
Then `getCurrentSession()` populates queue + now playing.

### 2.2 Search Overlay

- Full-screen sheet or overlay with search bar
- Reuse `UnifiedSearchView` (or a slim variant that only hits backend)
- Guest always searches via **Spotify Backend Proxy** → ISRC → Apple resolution (already implemented)
- "Add" sends `AddSongRequest` to `POST /api/v1/songs/add`
- On success: dismiss overlay, refresh queue (or rely on coordinator)

### 2.3 Add / Vote Action

- Same flow as main app: `SessionCoordinator.addSong()` / `vote()`
- Backend `queue_service` resolves Spotify → Apple via `SongMatchingService` ✅
- No changes needed for add logic

### 2.4 Guest Display Name (The "Added by" Problem)

If every anonymous guest shows as "Guest," the queue loses social context:

> Espresso – *Added by Guest*  
> Starboy – *Added by Guest*

**Fix:** One-time "What's your name?" prompt when the App Clip first opens.

| Aspect | Implementation |
|--------|-----------------|
| **Trigger** | Show name prompt only when `UserDefaults` has no stored display name |
| **Default** | Pre-fill text field with a **random fun name** (e.g. "Neon Giraffe", "Cosmic Badger", "Electric Panda") |
| **Storage** | `UserDefaults.standard` key: `appClipGuestDisplayName` – persists across App Clip launches for the same install |
| **Backend** | Use this name as `username` when creating/updating the anonymous user's profile in `users` table |
| **Result** | Queue shows "Added by Neon Giraffe", "Added by Cosmic Badger" – social without real login |

**Flow:**
1. App Clip launches → anonymous auth
2. Check `UserDefaults` for display name
3. If missing → show lightweight sheet: "What's your name?" with text field pre-filled with random fun name
4. User can accept default, edit, or type their own → save to `UserDefaults` + sync to backend profile
5. Proceed to queue view; all add/vote actions use this display name

**Random fun name pool:** Mix of adjective + animal (e.g. Neon Giraffe, Cosmic Badger, Electric Panda, Velvet Fox, Solar Penguin, Mystic Owl, Neon Dolphin, Turbo Sloth, Glow Worm, Cosmic Koala). Keep a curated list of ~20–30 names in code.

---

## Step 3: Associated Domains

### 3.1 The Website

You need a domain (e.g. `queueit.app`, `join.queueit.com`).

Options:
- **A:** Host a minimal site (e.g. Vercel/Netlify) that serves AASA
- **B:** Backend serves it: `GET https://queueit.app/.well-known/apple-app-site-association`

### 3.2 The AASA File

Create `apple-app-site-association` (no extension):

```json
{
  "appclips": {
    "apps": ["TEAMID.com.yourcompany.queueit.Clip"]
  },
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.queueit",
        "paths": ["/join", "/join/*"]
      }
    ]
  }
}
```

- `TEAMID` = your Apple Team ID
- Serve at: `https://queueit.app/.well-known/apple-app-site-association`
- Content-Type: `application/json` (no redirect)
- HTTPS required

### 3.3 The Link Format

- QR and share link: `https://queueit.app/join?code=PARTY123`
- Or path-based: `https://queueit.app/join/PARTY123`
- `code` = your `join_code` (4–20 chars from `CreateSessionView`)

### 3.4 Entitlements

- **Main app:** `applinks:queueit.app`, `webcredentials:queueit.app`
- **App Clip:** `appclips:queueit.app` (and/or `applinks` if you want main app to open when installed)

---

## Step 4: Default App Clip Link (No Website Yet)

If you don’t have a domain live yet, use **Default App Clip Links**:

- Format: `https://appclip.apple.com/id?p=com.yourcompany.queueit.Clip&code=PARTY123`
- Query params: `code` (or `sessionID` if you prefer)
- Works from iMessage, Notes, QR codes
- No AASA required for this path

**Caveat:** Less polished than Universal Links; best as an interim step.

---

## Step 5: App Clip Card (App Store Connect)

Before the Clip opens, the user sees a system card. Configure in App Store Connect:

| Setting | Suggestion |
|---------|------------|
| **Header Image** | Party scene or “Now Playing” UI (1200×630) |
| **Subtitle** | “Add songs and vote on the queue at this party.” |
| **Call to Action** | “Join” or “Play” |

---

## Phase 1 Implementation Checklist

### Auth & Backend

| Task | Detail | Status |
|------|--------|--------|
| **Anonymous Auth** | Add `AuthService.signInAnonymously()` using Supabase `signInAnonymously()` | ❌ |
| **Backend** | Supabase anonymous JWT works with `verify_jwt` (same JWKS) – no change | ✅ |
| **Profile for anonymous** | Create `users` row: `id`, `username` = display name from UserDefaults (or random fun name), `music_provider = "none"` | ❌ |
| **RLS** | Ensure anonymous users can join sessions and add songs (policy check) | Review |

### URL & Deep Link

| Task | Detail | Status |
|------|--------|--------|
| **URL Scheme** | Current scheme `com.queueit.app` is for OAuth; add `queueit` for join: `queueit://join?code=X` | Partial |
| **Associated Domains** | `applinks:queueit.app`, `appclips:queueit.app` in entitlements | ❌ |
| **AASA** | Host `apple-app-site-association` at domain | ❌ |
| **onContinueUserActivity** | Handle `.userActivity` for Universal Links; parse `code` | ❌ |
| **onOpenURL** | Handle custom scheme `queueit://join?code=X` | ❌ |

### Host Flow (Main App)

| Task | Detail | Status |
|------|--------|--------|
| **QR Generation** | Build `QRCodeView` with `CoreImage.CIFilter` (CIQRCodeGenerator) | ❌ |
| **Invite Button** | Add “Invite Friends” in `SessionView` / `HostControlsView` | ❌ |
| **Link** | `https://queueit.app/join?code=<join_code>` or Default App Clip link | ❌ |

### App Clip Target

| Task | Detail | Status |
|------|--------|--------|
| **New Target** | Create App Clip target in Xcode | ❌ |
| **Shared Files** | Add target membership for services, models, theme, components | ❌ |
| **Clip Entry** | Minimal `@main` struct: init auth (anonymous), API, coordinator | ❌ |
| **Clip UI** | Landing (queue) + search overlay only | ❌ |
| **Guest Name prompt** | One-time "What's your name?" sheet; random fun name default; store in UserDefaults; sync to backend profile | ❌ |
| **Bundle ID** | `com.yourcompany.queueit.Clip` | ❌ |

---

## Suggested Implementation Order

1. **Anonymous Auth** – `AuthService.signInAnonymously()` + backend/RLS validation
2. **URL Handling** – `onContinueUserActivity` + `onOpenURL` in main app (and later Clip)
3. **QR in Main App** – QR view, “Invite Friends”, link builder
4. **App Clip Target** – Create target, share files, minimal guest-only UI
5. **Associated Domains** – AASA + entitlements when domain is ready
6. **App Clip Card** – App Store Connect metadata

---

## Code Snippets for Discussion

### A. `onContinueUserActivity` (Universal Links)

```swift
// In QueueITApp or App Clip entry point
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL else { return }
    // queueit.app/join?code=PARTY123 or /join/PARTY123
    let code = parseJoinCode(from: url)
    if let code { sessionCoordinator.pendingJoinCode = code }
}
```

### B. `onOpenURL` (Custom Scheme + Default App Clip Link)

```swift
.onOpenURL { url in
    if url.scheme == "queueit", url.host == "join" {
        let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "code" }?.value
        if let code { sessionCoordinator.pendingJoinCode = code }
    }
    // Also handle appclip.apple.com links if needed
}
```

### C. Anonymous Auth in AuthService

```swift
func signInAnonymously() async throws {
    let session = try await client.auth.signInAnonymously()
    // Create minimal profile in 'users' table
    // Then loadProfile or set needsProfileSetup = false for Clip
}
```

### D. Guest Display Name (Random Fun Names + UserDefaults)

```swift
// AppClipGuestNameManager – shared or Clip-only
enum AppClipGuestName {
    static let storageKey = "com.queueit.clip.guestDisplayName"
    
    static var displayName: String {
        get {
            UserDefaults.standard.string(forKey: storageKey) ?? randomFunName
        }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
    
    static var hasSetName: Bool {
        UserDefaults.standard.string(forKey: storageKey) != nil
    }
    
    static var randomFunName: String {
        let adjectives = ["Neon", "Cosmic", "Electric", "Phantom", "Velvet", "Solar", "Pixel", "Lunar", "Stellar", "Prism"]
        let nouns = ["Giraffe", "Panda", "Fox", "Wolf", "Owl", "Dragon", "Phoenix", "Panther", "Raven", "Jaguar"]
        return "\(adjectives.randomElement()!) \(nouns.randomElement()!)"
    }
}
```

**Name prompt flow:** On first launch, if `!AppClipGuestName.hasSetName`, show a sheet:  
"What's your name?" with a TextField pre-filled with `AppClipGuestName.randomFunName`. User can edit or tap "Let's go!" to keep it. Save to `UserDefaults`; use this value when creating/updating the anonymous user's profile for "Added by X" in the queue.

### E. App Clip Entry Point

```swift
@main
struct QueueITClipApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var sessionCoordinator: SessionCoordinator
    
    init() {
        let supabaseURL = URL(string: "https://...")!
        let service = AuthService(...)
        _authService = StateObject(wrappedValue: service)
        let api = QueueAPIService(baseURL: backendURL, authService: service)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(apiService: api))
    }
    
    var body: some Scene {
        WindowGroup {
            AppClipGuestView()  // Queue + Search only
                .environmentObject(authService)
                .environmentObject(sessionCoordinator)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { ... }
        .onOpenURL { ... }
    }
}
```

---

## Open Questions

1. **Domain:** Do you own `queueit.app` or another domain? If not, Default App Clip Links are the short-term path.
2. **Anonymous vs Sign in with Apple:** For “Added by X”, is “Guest” acceptable, or do you want “Added by [Apple ID]” for guests?
3. **RealtimeService in Clip:** Poll `getCurrentSession()` periodically vs. adding WebSocket to Clip for live queue updates?
4. **Host QR placement:** Prefer a sheet from `SessionView`, or a dedicated tab/section in `HostControlsView`?
5. **RLS:** Can anonymous users (with Supabase anon JWT) join sessions and add songs under current RLS?

---

## Relation to QR Party SharePlay Strategy

This plan complements [QR_PARTY_SHAREPLAY_STRATEGY.md](./QR_PARTY_SHAREPLAY_STRATEGY.md):

- **Phase 1 (QR + Deep Link)** in that doc → implemented here for the **main app** (QR, URL handling)
- This doc adds the **App Clip** path → same backend, same flow, zero install for guests
- **Phase 2 (Guest Auth)** → Anonymous auth is the Clip-specific solution; link tokens remain an option for the main app
- **Phase 3 (GroupActivities)** → orthogonal; can be layered later

---

*Next: Confirm domain and auth approach, then we can sequence the implementation.*
