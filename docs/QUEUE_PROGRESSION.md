# Queue Progression Feature

This document describes how the automatic queue progression works in QueueIT - advancing to the next song when the current song finishes playing.

## Overview

When the host device plays a song from the shared queue, the app automatically detects when the song ends and advances to the next song. This involves:

1. **iOS App**: Detecting when a song finishes playing
2. **Backend API**: Marking the song as "played" and advancing to the next song
3. **iOS App**: Receiving the updated session and playing the next track

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (Host)                          │
├─────────────────────────────────────────────────────────────────┤
│  MusicManager                    SessionCoordinator             │
│  ┌─────────────────┐            ┌─────────────────┐            │
│  │ Detect song end │───────────▶│ handleSongFinished()        │
│  │ via polling     │            │                              │
│  │ + Combine       │            │ POST /song_finished          │
│  └─────────────────┘            │         │                    │
│                                 │         ▼                    │
│                                 │ refreshSession()             │
│                                 │         │                    │
│                                 │         ▼                    │
│                                 │ handleSessionChange()        │
│                                 │         │                    │
│                                 │         ▼                    │
│                                 │ playTrack(nextSong)          │
│                                 └─────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Backend API                             │
├─────────────────────────────────────────────────────────────────┤
│  POST /api/v1/sessions/song_finished                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1. Mark current song status = "played"                  │   │
│  │ 2. Get next queued song (highest votes, then oldest)    │   │
│  │ 3. Set next song status = "playing"                     │   │
│  │ 4. Update session.current_song to next song             │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Supabase DB                             │
├─────────────────────────────────────────────────────────────────┤
│  queued_songs.status: queued → playing → played/skipped        │
│  sessions.current_song: UUID of currently playing queued_song  │
└─────────────────────────────────────────────────────────────────┘
```

## Song Status Flow

```
queued ──▶ playing ──▶ played
              │
              └──────▶ skipped (if host skips)
```

- **queued**: Song is waiting in the queue
- **playing**: Song is currently playing (only ONE song should have this status per session)
- **played**: Song finished naturally
- **skipped**: Song was skipped by the host

## Implementation Details

### 1. Song End Detection (MusicManager.swift)

Apple Music's `ApplicationMusicPlayer` doesn't provide a reliable "song ended" callback. We use multiple detection strategies:

```swift
// Detection conditions checked every 1 second via polling:

// 1. Queue empty and not playing
let queueEmpty = currentEntry == nil
let notPlaying = playbackStatus != .playing
(queueEmpty && notPlaying)

// 2. Playback reached end of duration
let reachedEnd = playbackTime >= (duration - 1.0)
(reachedEnd && notPlaying)

// 3. Player stopped
playbackStatus == .stopped

// 4. Paused with empty queue
(playbackStatus == .paused && queueEmpty)

// 5. Stalled at end (playback time hasn't changed for 2+ polls near end)
stalledAtEnd = nearEnd && playbackStallCount >= 2

// 6. Reset after end (KEY DETECTION)
// Apple Music behavior: when song ends, it pauses and resets playbackTime to 0
// We track if we were recently near the end, then detect the reset
wasNearEnd = playbackTime >= (duration - 5.0)
resetAfterEnd = wasNearEnd && playbackStatus == .paused && playbackTime < 1.0
```

The **resetAfterEnd** detection is critical - Apple Music doesn't clear the queue entry when a song ends, it just pauses and resets playback time to 0.

### 2. Callback Chain (SessionCoordinator.swift)

When `MusicManager` detects song end:

```swift
private func handleSongFinished() async {
    guard isHost else { return }
    
    do {
        // Tell backend to advance queue
        try await apiService.songFinished()
        
        // Get updated session with new current song
        await refreshSession()
        
    } catch {
        // Retry once after 1 second
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        try await apiService.songFinished()
        await refreshSession()
    }
}
```

The `handleSessionChange()` observer detects when `currentSession.currentSong` changes and automatically plays the new track.

### 3. Backend Queue Advancement (session_service.py)

```python
def song_finished_for_user(auth: AuthenticatedClient) -> Dict[str, Any]:
    # 1. Mark current song as played
    if session_details.get("current_song"):
        queue_repo.update_song_status(current_song_id, "played")
    
    # 2. Advance to next song
    _advance_to_next_song(session_repo, queue_repo, session_id)

def _advance_to_next_song(session_repo, queue_repo, session_id):
    # Get next song (sorted by votes DESC, created_at ASC)
    next_song = queue_repo.get_next_queued_song(session_id)
    
    if next_song:
        queue_repo.update_song_status(next_song["id"], "playing")
        session_repo.set_current_song(session_id, next_song["id"])
    else:
        # No more songs, clear current_song
        session_repo.set_current_song(session_id, None)
```

### 4. Race Condition Prevention (queue_service.py)

When multiple songs are added simultaneously to an empty queue, we prevent multiple songs from being set as "playing":

```python
def add_song_to_queue_for_user(auth, request):
    queued = queue_repo.add_song_to_queue(...)
    
    # Atomic conditional update - only sets current_song if it's NULL
    was_set = session_repo.set_current_song_if_empty(
        session_id=session_row["id"],
        queued_song_id=queued["id"]
    )
    if was_set:
        queue_repo.update_song_status(queued["id"], "playing")
```

```python
# session_repo.py
def set_current_song_if_empty(self, session_id: str, queued_song_id: str) -> bool:
    response = (
        self.client
        .from_("sessions")
        .update({"current_song": queued_song_id})
        .eq("id", session_id)
        .is_("current_song", "null")  # Only update if NULL
        .execute()
    )
    return bool(response.data)
```

## API Endpoints

### POST /api/v1/sessions/song_finished

Called by the host when the current song finishes playing.

**Authorization**: Host only

**Response**:
```json
{"ok": true}
```

**Side effects**:
- Marks current song status as "played"
- Sets next song status as "playing"
- Updates session.current_song to next song (or NULL if queue empty)

### PATCH /api/v1/sessions/control_session

Used to skip the current track.

**Body**:
```json
{"skip_current_track": true}
```

**Side effects**:
- Marks current song status as "skipped"
- Advances to next song (same as song_finished)

## Database Schema

```sql
-- queued_songs status enum
CREATE TYPE song_status AS ENUM ('queued', 'playing', 'played', 'skipped');

-- Sessions table
CREATE TABLE sessions (
    id uuid PRIMARY KEY,
    join_code text UNIQUE NOT NULL,
    host_id uuid NOT NULL REFERENCES users(id),
    current_song uuid REFERENCES queued_songs(id),
    created_at timestamptz DEFAULT now()
);

-- Queued songs table
CREATE TABLE queued_songs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL REFERENCES sessions(id),
    added_by_id uuid NOT NULL REFERENCES users(id),
    status song_status NOT NULL DEFAULT 'queued',
    song_external_id text NOT NULL REFERENCES songs(external_id),
    created_at timestamptz DEFAULT now()
);
```

## Debugging

### iOS Logs to Watch

```
🎵 MusicManager: Starting playback of 'Song Name' (duration: 180.0s)
🔍 MusicManager: Poll #10 - status: playing, time: 10.0/180.0, queueEntry: true
🏁 MusicManager: Song finished (status: paused, ..., resetAfterEnd: true)
🎵 SessionCoordinator: onFinishedCallback triggered
🎵 SessionCoordinator: Song finished, advancing queue...
✅ SessionCoordinator: Backend acknowledged song finished
🔄 SessionCoordinator: Session changed - oldSong: X, newSong: Y
▶️ SessionCoordinator: Playing new track: Y
```

### Backend Logs to Watch

```
song_finished_called user_id=...
song_finished_processing session_id=... current_song_id=...
song_marked_as_played queued_song_id=...
advancing_to_next_song session_id=... next_song_id=... next_song_name=...
song_finished_complete session_id=... next_song_id=...
```

## Known Limitations

1. **Host device required**: Only the host device plays music. If the host leaves or loses connection, playback stops.

2. **No real-time sync**: Other users don't see queue updates in real-time (no WebSocket implementation yet). They need to refresh manually or wait for next API call.

3. **Apple Music only**: Currently only supports Apple Music playback. Spotify tracks are searched on Apple Music.

## Future Improvements

- [ ] WebSocket real-time updates for all session members
- [ ] Supabase Realtime subscription for queue changes
- [ ] Playback failure handling and retry
- [ ] Multiple host support / host transfer
