# Apple MusicKit Integration in QueueIT

This document outlines how Apple MusicKit has been integrated into the QueueIT application to handle actual music playback for session hosts.

## 1. MusicManager Service
The core of the Apple Music integration lives in `QueueIT/Services/MusicManager.swift`. This is an `@Observable` singleton class responsible for:
- Requesting authorization to use Apple Music (`requestAccess()`).
- Checking for an active Apple Music subscription (`checkSubscription()`).
- Searching the Apple Music catalog for songs by title and artist (`searchForSong(query:)`).
- Controlling the system's `ApplicationMusicPlayer` to play, pause, or stop songs.

## 2. Info.plist Permissions
To allow the app to request Apple Music access, the `NSAppleMusicUsageDescription` key was added to the `QueueIT/Info.plist`. This provides the system prompt message explaining why the app needs access:
```xml
<key>NSAppleMusicUsageDescription</key>
<string>QueueIT needs access to your Apple Music to play songs during your session.</string>
```

## 3. SessionCoordinator Playback Hook
The `QueueIT/Services/SessionCoordinator.swift` has been updated to hook into changes in the `currentSession`. 

When the `currentSession` updates (either via the initial API load or real-time WebSocket events), a `didSet` observer triggers the `handleSessionChange(oldValue:newValue:)` method:

1. **Host Check:** It first verifies if the current user is the host of the session (`isHost`). Only the host should play music.
2. **Song Change Detection:** It compares the ID of the `currentSong` from the `oldValue` to the `newValue`.
3. **Authorization & Playback:** If the song has changed to a new track:
   - It checks authorization and prompts the user if necessary.
   - It searches Apple Music using the track's name and artist.
   - It tells the `MusicManager` to play the found Apple Music `Song`.
4. **Stopping Playback:** If the `currentSong` becomes `nil` (e.g., the queue ends) or if the host leaves the session, it tells the `MusicManager` to stop playback.

## Flow Summary
1. A user creates a session and becomes the host.
2. A user adds a song to the queue via the API.
3. The WebSocket sends a `session.updated` or `now_playing.updated` event.
4. The `SessionCoordinator` refreshes the `currentSession`.
5. The `SessionCoordinator` notices a new `currentSong`.
6. As the host, the `SessionCoordinator` searches Apple Music for the track and begins playing it via the `MusicManager`.
