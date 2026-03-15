---
name: Checklist Keys Config Update
overview: Update the pre-launch checklist to align the Security, Configuration, and Token Storage sections with the `.xcconfig` + Info.plist strategy, APIConfig Swift enum, and Keychain-based Supabase token storage.
todos: []
isProject: false
---

# Pre-Launch Checklist: Keys & Config Update

## Current State

- [QueueITApp.swift](QueueIT/QueueIT/QueueITApp.swift) and [QueueITClipApp.swift](QueueIT/QueueITClip/QueueITClipApp.swift) hardcode Supabase URL, anon key, and backend URL
- AuthService uses Supabase default token storage (UserDefaults) – insecure for JWT/session tokens
- Checklist references `Config.plist` (lines 23–27); your proposed workflow uses `.xcconfig` (Apple-native, better for build configurations)

---

## Changes to [docs/pre-launch-checklist.md](docs/pre-launch-checklist.md)

### 1. Security Section (lines 22–29)

Replace the current Security section with the `.xcconfig` workflow:

- Rotate Supabase anon key (current key in git history)
- Create `Config-Debug.xcconfig` and `Config-Release.xcconfig` (do not add to Git)
- Add `BackendURL`, `SupabaseURL`, `SupabaseAnonKey` to Info.plist as `$(VAR_NAME)` references
- Assign configurations: Debug → Config-Debug, Release → Config-Release
- Add `*.xcconfig` to `.gitignore` (with `!Config.example.xcconfig` exception)
- Create `Config.example.xcconfig` with empty placeholders for onboarding
- Update main app and App Clip to read from config (via APIConfig; see Configuration section)

Note: Include the `https:/$()/` escape for double slashes in `.xcconfig`.

#### REMINDER: The `.xcconfig` Propagation Trap

A common pitfall: adding the `.xcconfig` file to the project but forgetting to assign it at the **Project** level. If you miss this, your Info.plist will literally contain the string `$(BACKEND_URL)` instead of the actual URL, causing your app to crash on launch.

**The fix:** In the Project Navigator, click the blue project icon → Info tab → Configurations. Manually expand "Debug" and "Release" and select your respective `.xcconfig` files for **each target** (main app and App Clip).

---

### 2. Configuration Section (lines 47–52)

Expand to include the APIConfig / Environment pattern:

- Create `APIConfig` or `Environment` enum that reads from `Bundle.main.infoDictionary`
- Use keys: `BackendURL`, `SupabaseURL`, `SupabaseAnonKey` (matching Info.plist)
- Replace force unwraps with `fatalError` on invalid/missing config (fail-fast at launch)
- Use build configuration (Debug vs Release) to select config source
- Ensure main app and App Clip share the same config source (Info.plist + xcconfig)
- Update preview mocks to use mock services instead of localhost

Add a reference to the Backend URL section: URLs will come from APIConfig, not hardcoded strings in `QueueITApp.swift` / `QueueITClipApp.swift`.

---

### 3. Token Storage Section (lines 78–81)

Expand with implementation details for Supabase Keychain storage:

- Implement `KeychainAuthStorage` conforming to Supabase `AuthStorage`
- Pass `auth: .init(storage: KeychainAuthStorage())` into `SupabaseClientOptions` when creating `SupabaseClient` in `AuthService`
- Replace UserDefaults-based token storage with Keychain (access_token, refresh_token)
- Optionally use SwiftKeychainWrapper or native Security framework
- Test token persistence across app restart and reinstall scenarios

Add a rationale note: UserDefaults is plain-text; Keychain is hardware-backed and encrypted.

---

### 4. Backend URL Section (lines 12–16)

Adjust to reflect the new config flow:

- Keep: deploy backend, replace ngrok URL
- Change: "Replace ngrok URL in QueueITApp.swift" → "Set production backend URL in `Config-Release.xcconfig`"
- Change: same for QueueITClipApp
- Change: "Add environment configuration" → already covered by xcconfig + APIConfig

---

### 5. Force Unwraps (lines 58–62)

- The item "Replace force unwrap in QueueITApp.swift backend URL" is addressed by APIConfig (centralized, fail-fast validation)
- Keep the item but clarify it's satisfied when APIConfig is used

---

### 6. Quick Reference Table (lines 137–145)

Update the table:

| Item                        | File(s)                                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Supabase keys / Backend URL | `Config-Release.xcconfig`, `Config-Debug.xcconfig`, `Info.plist`, `APIConfig.swift` (or `Environment.swift`) |
| Auth token storage          | `AuthService.swift` (SupabaseClientOptions), new `KeychainAuthStorage.swift`                                 |

---

### 7. Optional: Add "Where to put what" Summary

Add a small summary box (or link to a separate doc) reflecting your table:

| Data               | Storage                | Security           |
| ------------------ | ---------------------- | ------------------ |
| Backend URL        | .xcconfig → Info.plist | Low (easy to swap) |
| Supabase Anon Key  | .xcconfig → Info.plist | Medium             |
| User JWT / Session | Keychain               | High               |
| Feature Flags      | Remote Config (future) | High (dynamic)     |

---

## File-Level Implementation Reference (for follow-up work)

When implementing (not in this plan):

| Task                       | Files to create/modify                                                                                                                                          |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Create xcconfig files      | `QueueIT/Config-Debug.xcconfig`, `QueueIT/Config-Release.xcconfig`, `QueueIT/Config.example.xcconfig`                                                           |
| Update Info.plist          | `QueueIT/QueueIT/Info.plist`, `QueueIT/QueueITClip/Info.plist`                                                                                                  |
| Create APIConfig           | `QueueIT/QueueIT/Utilities/APIConfig.swift` (or `Environment.swift`)                                                                                            |
| Create KeychainAuthStorage | `QueueIT/QueueIT/Services/KeychainAuthStorage.swift`                                                                                                            |
| Update AuthService         | Pass `storage: KeychainAuthStorage()` to SupabaseClientOptions                                                                                                  |
| Update app entry points    | `QueueITApp.swift`, `QueueITClipApp.swift` – init AuthService and QueueAPIService with `APIConfig.backendURL`, `APIConfig.supabaseURL`, `APIConfig.supabaseKey` |
| .gitignore                 | Add `*.xcconfig` and `!Config.example.xcconfig` (or equivalent for your project layout)                                                                           |

---

## Checklist Definition of Done

Ensure the "Definition of Done" (lines 117–119) includes:

- No secrets in source code (keys in xcconfig, ignored by Git)
- Supabase session tokens stored in Keychain, not UserDefaults
