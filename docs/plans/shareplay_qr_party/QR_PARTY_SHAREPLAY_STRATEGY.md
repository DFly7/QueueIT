# QR Code Party: SharePlay Strategy for QueueIT (2026)

**Created:** March 14, 2026  
**Status:** Planning  
**Scope:** Apple-hosted sessions with zero-friction guest join, leveraging iOS 18+ SharePlay rules.

---

## Executive Summary

The strategy targets iOS 18+ (released late 2024) where **Apple officially loosened SharePlay rules**: only the host needs an Apple Music subscription; guests can add songs, vote, and participate without one. This document plans how QueueIT can deliver a "QR Code Party" experience that:

1. **Host** = sole subscription required; device acts as playback server
2. **Guests** = add, vote, search without subscription (Apple or Spotify)
3. **Entry** = QR code for zero-friction join
4. **Provider-agnostic** = Spotify guests search via proxy; ISRC resolves to Apple catalog

---

## Strategy Validation

### ✅ What Apple Confirms (iOS 18+)

| Fact | Source |
|------|--------|
| Only host needs Apple Music subscription | Apple Support, iOS 18 docs |
| Guests can add/remove from queue | iOS 18 SharePlay, tvOS 17.4+ |
| QR code join flow exists | HomePod/Apple TV SharePlay |
| Host approves/denies join requests | SharePlay flow |
| Works across geographic distances | iOS 18 release notes |

### ✅ What QueueIT Already Has

| Component | Status | Notes |
|-----------|--------|-------|
| **Spotify → Apple resolution** | ✅ Done | `SongMatchingService` (ISRC + fuzzy metadata) |
| **Backend queue** | ✅ Done | Supabase, votes, real-time |
| **Host-only playback** | ✅ Done | `MusicManager` on host device |
| **Provider-agnostic add** | ✅ Done | `queue_service` resolves to `host_provider` |
| **Unified search UI** | ✅ Done | `UnifiedSearchView` with provider routing |
| **QR join** | ❌ TODO | `JoinSessionView` has placeholder button |

### 🟡 Where We Need to Decide

| Topic | Options | Recommendation |
|-------|---------|----------------|
| **GroupActivities** | Use for join vs. skip | Phase 2 – optional; backend-first is simpler |
| **Guest auth** | Full sign-up vs. Apple ID vs. anonymous | Phase 1: keep Supabase auth; Phase 2: explore link tokens |
| **QR target** | Deep link vs. join code vs. SharePlay activity | Phase 1: `queueit://join?code=ABC12` |

---

## Requirements

### Functional Requirements

#### FR-1: QR Code Join (Zero-Friction Entry)

- **Host** sees a QR code in the app that encodes join information.
- **Guest** scans with iPhone Camera → opens QueueIT (or App Store if not installed) with pre-filled join.
- **Minimal taps**: Guest lands in session with minimal prompts.

**Acceptance criteria:**

- [ ] Host can display QR code from `SessionView` or `HostControlsView`
- [ ] QR encodes: `queueit://join?code=<join_code>` (or equivalent)
- [ ] Scan opens app to `JoinSessionView` with code pre-filled; user taps "Join" (or auto-join if signed in)
- [ ] Works with Universal Links / custom URL scheme

#### FR-2: Guest Add Without Subscription (Apple-Hosted)

- When host uses **Apple Music** (`host_provider == "apple"`), guests can add songs without their own Apple Music subscription.
- Guests use their chosen search source (Spotify backend, Apple Music, or None).
- Backend resolves to host catalog before adding to queue.

**Acceptance criteria:**

- [ ] Guest with `music_provider = "none"` can add to Apple-hosted session (search via backend Spotify)
- [ ] Guest with `music_provider = "spotify"` can add to Apple-hosted session (search via backend Spotify; ISRC resolution)
- [ ] Guest with `music_provider = "apple"` can add directly via MusicKit
- [ ] Rejection when song not in host catalog: "This song isn't available on Apple Music. Try another."

*(Most of this exists; verify edge cases.)*

#### FR-3: Spotify Guest at Apple Party (Search Proxy)

- Guest selects Spotify as search source.
- Backend receives Spotify track ID → fetches ISRC → resolves to Apple Music catalog.
- Host's queue receives Apple Music track.

**Acceptance criteria:**

- [ ] Backend `SongMatchingService.resolve_spotify_to_apple()` used in add flow
- [ ] UI shows "Added to queue!" with correct track metadata
- [ ] No Spotify playback by guest; no Spotify API usage beyond search + metadata

*(Implemented in `queue_service.add_song_to_queue_for_user`.)*

#### FR-4: Single Subscriber Model

- Only the **host** must have an active subscription (Apple Music or Spotify, per `host_provider`).
- Guests never stream; they only add/vote. Playback happens on host device only.

**Acceptance criteria:**

- [ ] No subscription check for guests on add or vote
- [ ] Host must have valid MusicKit/Spotify token to create session and play
- [ ] Clear error if host loses subscription mid-session

### Non-Functional Requirements

#### NFR-1: iOS Version

- Target **iOS 18+** for SharePlay-related features (if we use GroupActivities).
- Phase 1 QR + deep link can support iOS 16+.

#### NFR-2: Auth and Privacy

- Guests need some identity for "Added by X" and votes.
- Options:
  - **A:** Full Supabase auth (current) – highest friction
  - **B:** Sign in with Apple only – medium friction, good for many guests
  - **C:** Join link token – guest gets temp identity, no sign-up

*Phase 1 uses A; Phase 2 explores B/C.*

#### NFR-3: Backward Compatibility

- Sessions created by hosts on older iOS should still work for join and add.
- SharePlay-specific features (if any) gracefully degrade on older OS.

---

## Architecture Options

### Option A: Backend-First (Recommended for Phase 1)

```
┌─────────────────┐     QR scan      ┌─────────────────┐
│  Guest Camera   │ ───────────────▶ │  QueueIT App    │
└─────────────────┘   queueit://join │  (deep link)    │
                                     └────────┬────────┘
                                              │
                     ┌────────────────────────┼────────────────────────┐
                     │                        ▼                        │
                     │  ┌─────────────────────────────────────────┐   │
                     │  │  Backend (Supabase + API)                │   │
                     │  │  - sessions, queue, votes, real-time     │   │
                     │  │  - add song (Spotify→Apple resolution)   │   │
                     │  └─────────────────────────────────────────┘   │
                     │                        ▲                        │
                     │                        │                        │
                     │  ┌─────────────────────┴─────────────────────┐  │
                     │  │  Host Device (Apple Music)                │  │
                     │  │  - MusicManager plays from backend queue  │  │
                     │  │  - Displays QR code                      │  │
                     │  └─────────────────────────────────────────┘  │
                     └────────────────────────────────────────────────┘
```

**Pros:** No new frameworks; reuses current backend; fastest to ship.  
**Cons:** Guests still need Supabase auth.

### Option B: GroupActivities Augmented (Phase 2)

```
┌─────────────────┐                    ┌─────────────────┐
│  Guest          │  GroupSession      │  Host           │
│  - Add song     │◀─────────────────▶│  - Plays music  │
│  - Vote         │  (optional sync)   │  - QR code      │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │         ┌──────────────────┐         │
         └────────▶│  Backend         │◀────────┘
                   │  (source of truth)│
                   └──────────────────┘
```

**Use case:** If we want SharePlay's native join UI (e.g. system sheet) or synchronized metadata display.  
**Requires:** `GroupActivity` conformance, `GroupSession` handling, iOS 15+ (better support in 18).

---

## Implementation Plan

### Phase 1: QR Code + Deep Link (4–6 days)

**Goal:** Host displays QR; guest scans and joins with minimal friction.

| Task | Owner | Est. |
|------|-------|------|
| 1. Add URL scheme `queueit` to app (Info.plist) | iOS | 0.5d |
| 2. Create `queueit://join?code=<join_code>` URL builder | iOS | 0.5d |
| 3. Add QR code view component (SwiftUI + CoreImage or package) | iOS | 1d |
| 4. Show QR in `SessionView` for host (tab or sheet) | iOS | 0.5d |
| 5. Implement QR scanner in `JoinSessionView` (replace TODO) | iOS | 1.5d |
| 6. Handle deep link on launch and when app already open | iOS | 1d |
| 7. Test: Host creates → displays QR → Guest scans → joins | QA | 0.5d |

**Deliverables:**

- Host can tap "Show QR" and display scannable code
- Guest can scan with Camera, open app, join with one tap (if signed in)
- Existing backend and auth unchanged

### Phase 2: Guest Auth Flexibility (1–2 weeks)

**Goal:** Reduce friction for guests who only want to join a party.

| Task | Est. |
|------|------|
| Explore "Join with Apple ID" (anonymous or non-anonymous) | 2d |
| Add optional join-link token: `queueit://join?token=<short_lived>` | 3d |
| Backend: generate token on session create; validate on join | 2d |
| Guest without account: create anonymous session or prompt Sign in with Apple | 2d |
| Testing and edge cases | 2d |

**Decision point:** Do we need anonymous guests, or is Sign in with Apple sufficient?

### Phase 3: GroupActivities (Optional)

**Goal:** Use SharePlay for native join UX and/or metadata sync.

| Task | Est. |
|------|------|
| Define `QueueITPartyActivity: GroupActivity` | 1d |
| Host: prepare and share activity; display QR that encodes activity | 2d |
| Guest: join via system SharePlay sheet | 2d |
| Send "add song" message via `GroupSession` to host (or keep backend) | 2d |
| Decide: backend vs. GroupSession as source of truth for queue | 1d |

**Risk:** GroupActivities is powerful but adds complexity. Only pursue if Phase 1 join friction remains high.

---

## Technical Decisions

### 1. QR Code Generation

- **Library:** Native `CoreImage.CIFilter` (`CIQRCodeGenerator`) is sufficient.
- **Content:** `https://queueit.app/join?code=ABC12` (Universal Link) or `queueit://join?code=ABC12` (custom scheme).
- **Recommendation:** Use both – Universal Link for web fallback, custom scheme for app.

### 2. Deep Link Handling

```swift
// In QueueITApp or @main app
.onOpenURL { url in
    guard url.scheme == "queueit", url.host == "join" else { return }
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
    // Navigate to JoinSessionView with pre-filled code
}
```

### 3. GroupActivity (If Used)

```swift
struct QueueITPartyActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "QueueIT Party"
        meta.type = .listenTogether  // or custom
        return meta
    }
}
```

*Exact API depends on iOS version and SharePlay docs.*

### 4. Spotify Proxy (Already Implemented)

Flow in `queue_service.add_song_to_queue_for_user`:

1. Guest sends `AddSongRequest` with `source: "spotify"`, `id: spotify_track_id`
2. If `host_provider == "apple"`: call `matching_service.resolve_spotify_to_apple()`
3. Backend uses resolved `apple_id` to add to queue
4. Host's `MusicManager` plays from queue (Apple Music catalog)

No changes needed for Spotify guest support.

---

## Guest Experience Comparison

| User Type | View Queue | Vote | Add Songs | Subscription Required |
|-----------|------------|------|-----------|------------------------|
| **Apple Music Host** | ✅ | ✅ | ✅ | **Yes** |
| **Apple Music Guest** | ✅ | ✅ | ✅ (MusicKit or backend) | No |
| **Spotify Guest** | ✅ | ✅ | ✅ (backend proxy → ISRC) | No |
| **None Guest** | ✅ | ✅ | ✅ (backend Spotify search) | No |

---

## Open Questions

1. **Universal Links:** Do we have a domain and `apple-app-site-association` for `queueit.app` or similar?
2. **Anonymous guests:** Do we need "Add by Anonymous" or is "Add by [Apple ID name]" acceptable?
3. **GroupActivities priority:** Is Phase 3 worth the complexity, or is Phase 1 QR + deep link enough for v1?
4. **Spotify Dev Mode:** Is the 1-user developer key still sufficient for backend search? (It should be – we're not streaming, just metadata.)

---

## Next Steps

1. **Approve plan** – Confirm Phases 1–3 scope and priorities.
2. **Phase 1 kickoff** – Implement QR display + scanner + deep link.
3. **Write Swift snippet** – If desired, add a high-level `GroupSession` send/receive example for "add song" for Phase 3 reference.

---

*This plan aligns QueueIT with iOS 18 SharePlay rules while preserving the existing backend and provider-agnostic architecture.*
