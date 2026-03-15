# Queue Advancement Feature

## Overview
Implemented automatic queue advancement so when a song ends (either naturally or is skipped), the next song in the queue automatically moves to "playing" status.

## Changes Made

### Backend Changes

#### 1. **New Repository Methods** (`app/repositories/queue_repo.py`)
- **`get_next_queued_song(session_id)`**: Gets the next song in the queue (highest votes, oldest first) with status='queued'
- **`update_song_status(queued_song_id, new_status)`**: Updates a queued song's status (queued → playing → played/skipped)

#### 2. **Updated Session Service** (`app/services/session_service.py`)
- **`_advance_to_next_song()`**: Helper function that:
  - Gets the next queued song
  - Updates its status to 'playing'
  - Sets it as session.current_song
  - If no songs left, clears current_song

- **Updated `control_session_for_user()`**: When skipping:
  - Marks current song as 'skipped'
  - Calls `_advance_to_next_song()`

- **New `song_finished_for_user()`**: Called when song finishes naturally:
  - Marks current song as 'played'
  - Calls `_advance_to_next_song()`

#### 3. **New API Endpoint** (`app/api/v1/sessions.py`)
- **POST `/api/v1/sessions/song_finished`**: Host-only endpoint for marking song completion

#### 4. **Database RLS Policy**
Added UPDATE policy for `queued_songs` table:
```sql
CREATE POLICY "Enable update for session host" ON public.queued_songs 
FOR UPDATE 
USING (session_id IN (SELECT id FROM public.sessions WHERE host_id = auth.uid())) 
WITH CHECK (session_id IN (SELECT id FROM public.sessions WHERE host_id = auth.uid()));
```

### Frontend Changes (iOS)

#### 1. **Updated MusicManager** (`Services/MusicManager.swift`)
- Added `Combine` framework for playback monitoring
- **`play(song:onFinished:)`**: Now accepts callback for when song finishes
- **`startMonitoringPlayback()`**: Monitors playback state changes
- **`checkIfSongFinished()`**: Detects when player stops and queue is empty
- **`stop()`**: Cleans up monitoring subscriptions

#### 2. **Updated SessionCoordinator** (`Services/SessionCoordinator.swift`)
- **`playTrack()`**: Passes callback to MusicManager
- **New `handleSongFinished()`**: Calls backend endpoint and refreshes session

#### 3. **Updated QueueAPIService** (`Services/QueueAPIService.swift`)
- **New `songFinished()`**: Makes POST request to `/song_finished` endpoint

## Flow Diagram

### Skip Song Flow
```
User clicks "Skip" 
→ SessionCoordinator.skipCurrentTrack() 
→ API: PATCH /control_session (skip_current_track: true)
→ Backend marks current as 'skipped'
→ Backend gets next queued song
→ Backend sets next song to 'playing' 
→ Backend updates session.current_song
→ Frontend refreshes session
→ SessionCoordinator detects new current_song
→ MusicManager plays new song
```

### Natural Song End Flow
```
Song finishes playing
→ MusicManager detects playback stopped
→ MusicManager calls onFinished() callback
→ SessionCoordinator.handleSongFinished()
→ API: POST /song_finished
→ Backend marks current as 'played'
→ Backend gets next queued song
→ Backend sets next song to 'playing'
→ Backend updates session.current_song
→ Frontend refreshes session
→ SessionCoordinator detects new current_song
→ MusicManager plays new song
```

## Song Status States
- **queued**: Default state when added to queue
- **playing**: Currently playing (session.current_song points to it)
- **played**: Finished playing naturally
- **skipped**: Skipped by host

## Testing
1. Create a session as host
2. Add multiple songs to the queue
3. The first song should automatically start playing
4. Wait for song to finish OR click "Skip Current Track"
5. The next song in the queue should automatically start playing
6. Verify song statuses are updated correctly in the database

## Notes
- Only the host can skip songs or mark them as finished
- Queue is sorted by votes (descending), then creation time (ascending)
- When no songs are left in queue, current_song is set to null
- Frontend automatically detects current_song changes via SessionCoordinator observer
