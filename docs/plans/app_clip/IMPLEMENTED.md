# App Clip & Universal Links — Implemented

**Date:** March 2026

---

## What Was Done

### GitHub Pages (`pages/`)

New directory at repo root, served via GitHub Pages on `queueitapp.com`.

| File | Purpose |
|------|---------|
| `.nojekyll` | Bypasses Jekyll so all files (including `.well-known`) are served as static assets |
| `CNAME` | Custom domain: `queueitapp.com` |
| `.well-known/apple-app-site-association` | AASA — links domain to both app targets for Universal Links (applinks) and App Clip invocations (appclips) |
| `join.html` | `/join?code=X` landing page with Smart App Banner to trigger the App Clip card in iOS Safari |
| `index.html` | Simple marketing landing page |

**AASA covers:**
- `applinks` → `V8S6S975CD.DF.QueueIT12` on paths `/join*`
- `appclips` → `V8S6S975CD.DF.QueueIT12.Clip`

---

### `InviteView.swift`

`joinURL` fixed from broken placeholder:
```
https://appclip.apple.com/id?p=com.yourcompany.queueit.Clip&code=X
```
to the real Universal Link:
```
https://queueitapp.com/join?code=X
```
Fixes both the QR code and the Share Link button.

---

### Entitlements

| File | Change |
|------|--------|
| `QueueITClip/QueueITClip.entitlements` | Added `appclips:queueitapp.com` |
| `QueueIT/QueueIT.entitlements` *(new)* | Created with `applinks:queueitapp.com` |

> **Xcode action required:** Assign `QueueIT.entitlements` to the main app target via Signing & Capabilities → Code Signing Entitlements, or add Associated Domains via the + Capability button.

---

### `AppClipGuestName.swift`

Fixed force-unwrap crash: `randomElement()!` → `randomElement() ?? "Neon"` / `?? "Panda"`.

---

## Remaining Manual Steps

1. **GitHub Pages** — Repo Settings → Pages → source: `main`, folder: `/pages`, custom domain: `queueitapp.com`
2. **DNS** — Point `queueitapp.com` A records to GitHub Pages IPs; add `www` CNAME
3. **Xcode** — Wire `QueueIT.entitlements` to the main app target
4. **App Store Connect** — Configure default App Clip experience (header image, subtitle, CTA) after first build upload
5. **Smart App Banner** — Add `app-id=YOUR_APP_STORE_ID` to `join.html` once published
