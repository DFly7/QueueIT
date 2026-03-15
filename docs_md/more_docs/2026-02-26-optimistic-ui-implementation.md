# Optimistic UI Implementation - QueueIT iOS App

**Date:** February 26, 2026

## Overview

Implemented optimistic UI updates for the QueueIT iOS music queue app to provide instant visual feedback for user actions before server confirmation.

## Features Implemented

### 1. Optimistic Voting
- **Instant vote count updates**: When a user votes up or down, the vote count updates immediately in the UI
- **Button state highlighting**: Vote buttons show active state immediately when tapped
- **Server reconciliation**: After the API responds, the UI updates with the server's authoritative vote count

### 2. Optimistic Song Addition
- **Pending state display**: Songs appear in the queue immediately with a "Adding..." indicator
- **Loading overlay**: Pending songs show a progress spinner on the album art
- **Automatic refresh**: Once the server confirms, the pending song is replaced with the real data

### 3. Optimistic Skip (Host only)
- **Immediate track hide**: When the host skips a track, the now playing card hides immediately
- **Session refresh**: The queue updates with the next track after server confirmation

### 4. Auto-dismiss Login Sheet
- Added `onChange` observer on `AuthView` to automatically dismiss the authentication sheet when the user successfully logs in

### 5. Queue Reordering on Vote
- Queue now re-sorts in real-time based on optimistic vote counts
- Higher voted songs appear first, with ties broken by add time

## Technical Implementation

### State Management (SessionCoordinator.swift)

```swift
// Optimistic UI state
@Published var userVotes: [UUID: Int] = [:]           // User's vote per song (1, -1, or 0)
@Published var displayedVoteCounts: [UUID: Int] = [:] // Displayed vote counts
@Published var pendingSongs: [QueuedSongResponse] = [] // Songs being added
@Published var optimisticSkip: Bool = false           // Track being skipped

private var votesInFlight: Set<UUID> = []             // Prevent overwrites during API calls
private var pendingVoteValues: [UUID: Int] = [:]      // Queue rapid votes
```

### Vote Flow
1. User taps vote button
2. `userVotes` and `displayedVoteCounts` update immediately
3. If a vote is already in-flight for this song, the new value is queued
4. API request is sent
5. Server response updates `displayedVoteCounts` with authoritative value
6. Any pending vote is sent as a follow-up request

### Race Condition Prevention
- `votesInFlight` set tracks songs with active API calls
- `populateDisplayedVoteCounts()` skips songs in `votesInFlight` to prevent WebSocket refresh from overwriting optimistic values
- `pendingVoteValues` ensures rapid vote spamming doesn't cause UI glitches

## Bug Fix: UUID Case Mismatch

### The Problem
After implementing optimistic UI, the server was returning `total_votes = 0` for every vote, causing the UI to flicker from the correct optimistic value back to zero.

### Root Cause
**UUID case sensitivity mismatch between iOS and Supabase:**

- iOS sends UUIDs in **uppercase**: `0E510118-2C04-46A1-AA96-15462387410C`
- Supabase stores and returns UUIDs in **lowercase**: `0e510118-2c04-46a1-aa96-15462387410c`

In the backend's `_fetch_votes_sum_map()` function, the dictionary lookup used the original uppercase ID as the key, but the dictionary was populated with lowercase keys from Supabase:

```python
# Bug: uppercase key doesn't match lowercase key in dictionary
total = self._fetch_votes_sum_map({queued_song_id}).get(queued_song_id, 0)
# Returns 0 because 'ABC-123' != 'abc-123'
```

### The Fix
```python
# Fix: normalize to lowercase for dictionary lookup
total = self._fetch_votes_sum_map({queued_song_id}).get(queued_song_id.lower(), 0)
```

**File:** `QueueITbackend/app/repositories/queue_repo.py`

### Debug Process
1. Added logging to iOS `SessionCoordinator` to trace vote flow
2. Observed: optimistic update showed correct value, then server returned 0
3. Added logging to backend `_fetch_votes_sum_map()`
4. Discovered the case mismatch in terminal output:
   ```
   🗳️ _fetch_votes_sum_map: querying for queued_ids = ['0E510118-2C04-46A1-AA96-15462387410C']
   🗳️ _fetch_votes_sum_map: got 1 vote rows: [{'queued_song_id': '0e510118-2c04-46a1-aa96-15462387410c', ...}]
   🗳️ _fetch_votes_sum_map: totals = {'0e510118-2c04-46a1-aa96-15462387410c': 1}
   ```
5. Applied `.lower()` fix

## Files Modified

### iOS App (QueueIT/QueueIT/)
- `Services/SessionCoordinator.swift` - Core optimistic state management
- `Views/Components/QueueItemCard.swift` - Vote display and button highlighting
- `Views/Components/NowPlayingCard.swift` - Vote display for current track
- `Views/AppleMusicSearchView.swift` - Optimistic song addition UI
- `Views/RootView.swift` - Auto-dismiss login sheet
- `Models/Session.swift` - Made `votes` mutable, added helper methods
- `Models/User.swift` - Added convenience initializer for pending songs

### Backend (QueueITbackend/app/)
- `repositories/queue_repo.py` - Fixed UUID case mismatch, added structlog

## Lessons Learned

1. **Always normalize UUIDs** when working across different systems - case sensitivity can cause subtle bugs
2. **Add logging early** in the debugging process to trace data flow
3. **Race conditions are common** in optimistic UI - use in-flight tracking and request queuing
4. **WebSocket events can race** with API responses - protect optimistic state from being overwritten prematurely
