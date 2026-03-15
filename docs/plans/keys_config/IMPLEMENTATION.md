# Keys & Config Implementation

## What Was Done

Moved hardcoded Supabase keys, backend URL, and auth token storage out of source code into config files and secure storage.

## Why

- **Secrets in git**: Supabase anon key was committed; rotation required.
- **Environment switching**: No clean way to swap dev (ngrok) vs prod URLs.
- **Token storage**: UserDefaults is plain-text; Keychain is encrypted at rest.

## How

| Component | Implementation |
|-----------|----------------|
| **Config values** | `.xcconfig` files (Config-Debug, Config-Release) feed `$(VAR)` into Info.plist; APIConfig.swift reads at runtime |
| **Secrets** | `*.xcconfig` in .gitignore; Config.example.xcconfig committed as template |
| **Auth tokens** | KeychainLocalStorage (Supabase built-in) passed to SupabaseClientOptions |
| **App entry points** | QueueITApp.swift and QueueITClipApp.swift use APIConfig.backendURL, .supabaseURL, .supabaseAnonKey |

## Files Changed

- Created: Config-Debug.xcconfig, Config-Release.xcconfig, Config.example.xcconfig, APIConfig.swift
- Updated: both Info.plist (added BackendURL, SupabaseURL, SupabaseAnonKey), AuthService (Keychain storage), app entry points, .gitignore, project.pbxproj

## Xcode Setup Required

Assign xcconfigs in Project → Info → Configurations for each target. See [QueueIT/XCODE_SETUP_INSTRUCTIONS.md](../../QueueIT/XCODE_SETUP_INSTRUCTIONS.md).
