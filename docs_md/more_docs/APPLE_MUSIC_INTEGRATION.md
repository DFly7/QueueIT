# Apple Music Integration Implementation

## Overview
Migrated from Spotify search to Apple Music native search, enabling exact song matching and eliminating search ambiguity during playback.

## Database Changes

### Schema Updates
1. **Renamed `spotify_id` → `external_id`** in `songs` table
   - Now stores either Spotify IDs or Apple Music catalog IDs
   
2. **Added `source` column** to `songs` table
   - Type: `VARCHAR(20)` 
   - Default: `'spotify'`
   - Values: `'spotify'` or `'apple_music'`

3. **Updated Foreign Keys**
   - `queued_songs.song_spotify_id` → `queued_songs.song_external_id`
   - Constraint renamed to `queued_songs_song_external_id_fkey`

## Backend Changes

### Updated Files
1. **`app/schemas/track.py`**
   - Added `source` field to `TrackOut` and `AddSongRequest`
   - Changed alias from `spotify_id` to `external_id`
   - Added `Literal["spotify", "apple_music"]` type for source validation

2. **`app/repositories/song_repo.py`**
   - `get_by_spotify_id()` → `get_by_external_id()`
   - `upsert_song()` now accepts `external_id` and `source` parameters

3. **`app/repositories/queue_repo.py`**
   - `song_spotify_id` → `song_external_id` throughout
   - Updated batch fetch methods

4. **`app/services/queue_service.py`**
   - Updated to pass `source` when upserting songs

## Frontend Changes

### New Files
1. **`Extensions/Song+Track.swift`**
   - Extension to convert `MusicKit.Song` → `Track`
   - Automatically sets `source: .appleMusic`
   - Extracts all required metadata from Apple Music

2. **`Views/AppleMusicSearchView.swift`**
   - Full Apple Music search UI
   - Real-time search as you type
   - Results show album art, song name, artist, album
   - Add button to queue songs

### Updated Files
1. **`Models/Track.swift`**
   - Added `MusicSource` enum (`spotify`, `appleMusic`)
   - Added `source: MusicSource` property

2. **`Models/AddSongRequest.swift`**
   - Added `source: String` field
   - Updated initializer to include source from Track

3. **`Services/MusicManager.swift`**
   - Added `searchCatalog(query:limit:)` - Search Apple Music, return array of Songs
   - Added `playByCatalogID(_:onFinished:)` - Play directly by Apple Music ID (no search!)

4. **`Services/SessionCoordinator.swift`**
   - Updated `playTrack()` to check source:
     - If `apple_music`: Play directly by catalog ID ✅
     - If `spotify`: Fallback to text search 🔍

## How It Works

### Old Flow (Spotify)
```
User searches Spotify → Backend API → User adds song →
Backend stores Spotify ID → Host plays → 
Frontend searches Apple Music by text → Ambiguous results 😕
```

### New Flow (Apple Music)
```
User searches Apple Music → Frontend MusicKit → User adds song →
Backend stores Apple Music ID + source="apple_music" →
Host plays → Frontend plays by ID directly → Exact match! 🎯
```

## Usage

### For Users
Replace `SearchView` with `AppleMusicSearchView` in your navigation:
```swift
.sheet(isPresented: $showSearch) {
    AppleMusicSearchView()
        .environmentObject(sessionCoordinator)
}
```

### Converting Apple Music Songs
```swift
// Get song from Apple Music search
let song: Song = ...

// Convert to Track for backend
let track = song.toTrack()

// Add to queue
await sessionCoordinator.addSong(track: track)
```

## Benefits

### ✅ Exact Song Matching
- No ambiguity when playing
- Same recording every time
- No "Live" vs "Studio" confusion

### ✅ Performance
- Direct playback by catalog ID
- No search latency when playing
- Instant song start

### ✅ Better UX
- Native Apple Music search
- Shows actual Apple Music results
- What you see is what you hear

### ✅ Backward Compatible
- Spotify songs still work
- Text search fallback for Spotify tracks
- Existing songs in DB still play

## Migration Notes

### Existing Data
- All existing songs have `source='spotify'` (default)
- They will continue to use text search playback
- New Apple Music songs get exact playback

### Mixed Sessions
- Sessions can have both Spotify and Apple Music songs
- Each song plays according to its source
- Seamless experience for users

## Testing

1. ✅ Search Apple Music → Should show results with album art
2. ✅ Add Apple Music song → Should appear in queue
3. ✅ Play Apple Music song → Should play exact track (no search)
4. ✅ Skip to next song → Should advance correctly
5. ✅ Mixed queue → Both Spotify and Apple Music songs should work

## Future Enhancements

- [ ] Remove Spotify entirely and go Apple Music-only
- [ ] Add song source indicator in UI
- [ ] Cache Apple Music searches
- [ ] Batch fetch for multiple Apple Music IDs
