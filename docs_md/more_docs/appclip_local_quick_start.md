# App Clip Local Setup: Quick Guide

Since you got this working without the `?mode=developer` flag, it means your DNS and AASA file propagation were fast enough for Apple's standard services to pick them up. Here is the brief breakdown:

## 1. Web Configuration

- **Domain:** `https://queueitapp.com`
- **File:** `.well-known/apple-app-site-association`
- **Hosting:** GitHub Pages with Enforce HTTPS enabled
- **Content:** JSON linking `V8S6S975CD.DF.QueueIT12.Clip` to the `/join*` path

## 2. Xcode Entitlements

- **Target:** QueueITClip
- **Capability:** Associated Domains

**Entries:**

- `appclips:queueitapp.com`
- `applinks:queueitapp.com`

## 3. iOS Local Experience

- **Settings:** Settings → Developer → Local Experiences
- **URL Prefix:** `https://queueitapp.com/join`
- **Bundle ID:** `DF.QueueIT12.Clip` (excluding Team ID)
- **Activation:** iPhone must have the App Clip build installed via Xcode to cache the executable

## 4. Verification

- **Notes App:** Type the full URL and long-press
- **Result:** System displays "Open App Clip" menu option
