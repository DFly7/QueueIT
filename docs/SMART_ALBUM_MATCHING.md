# Smart Album Artwork Matching

## Problem

When resolving Spotify tracks to Apple Music via ISRC, multiple versions of the same recording often exist with different artwork:
- Single releases with single artwork
- Album versions with album artwork
- Deluxe editions with different covers
- Compilation appearances
- Remastered versions

Previously, the system blindly selected the first result, causing artwork mismatches even when the audio was correct (same ISRC = same recording).

## Solution: Intelligent Scoring System

### Version Selection Scoring

When multiple Apple Music versions match the same ISRC, the system uses a scoring algorithm:

| Criteria | Points | Description |
|----------|--------|-------------|
| **Compilation penalty** | -100 | Heavy penalty for "NOW That's What I Call Music", "Greatest Hits", etc. when Spotify showed original |
| **Original release boost** | +40 | Boost non-compilation albums (standalone releases) |
| **Exact album match** | +100 | Album name matches Spotify exactly (case-insensitive) |
| **Fuzzy album match (strong)** | +50 | Album name similarity > 80% (e.g., "Seventeen Going Under" vs "Seventeen Going Under (Deluxe)") |
| **Fuzzy album match (weak)** | +25 | Album name similarity > 50% (partial matches) |
| **Track count type match** | +30 | Both are singles (≤3 tracks) OR both are albums (>3 tracks) |
| **Both singles preference** | +20 | Extra boost when Spotify showed a single and Apple version is also a single |

### How It Works

1. **Fetch Spotify metadata**: Get album name and track count from Spotify
2. **Search Apple Music by ISRC**: Get all versions with matching ISRC
3. **Score each version**: Apply scoring criteria above
4. **Select highest score**: Choose the version with the best match
5. **Detailed logging**: Log all scores and match reasons for debugging

### Example: "Rein Me In" by Zak Abel (with Olivia Dean)

**Spotify shows**: "Rein Me In (with Olivia Dean) - Single" (1 track)

**Apple Music ISRC returns**:
- Version A: "Rein Me In (with Olivia Dean) - Single" → **Score: 190** (exact album + original + track type + both singles)
- Version B: "NOW That's What I Call Music! 122" → **Score: -100** (compilation penalty)

**Selected**: Version A ✅ (correct single artwork, not compilation)

### Example: "Will We Talk" by Sam Fender

**Spotify shows**: "Will We Talk - Single" (3 tracks)

**Apple Music ISRC returns**:
- Version A: "Will We Talk - Single" (3 tracks) → **Score: 190** (exact album + original + track type + both singles)
- Version B: "Seventeen Going Under" (11 tracks) → **Score: 40** (original release only)
- Version C: "Seventeen Going Under (Deluxe)" (14 tracks) → **Score: 40** (original release only)

**Selected**: Version A ✅ (correct single artwork)

## Implementation Details

### Files Modified

1. **`app/services/apple_music_service.py`**
   - Added `_string_similarity()` helper using `difflib.SequenceMatcher`
   - Enhanced `search_by_isrc()` with scoring parameters:
     - `preferred_album` (from Spotify)
     - `spotify_track_count` (for single detection)
   - Implements scoring logic and detailed logging

2. **`app/services/song_matching_service.py`**
   - Extracts `spotify_album_track_count` from Spotify API
   - Passes album metadata to ISRC search

### Key Code Locations

```python
# Fuzzy string matching
def _string_similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

# Scoring logic
score = 0

# Detect compilations
if _is_compilation_album(apple_album):
    if not _is_compilation_album(preferred_album):
        score -= 100  # Heavy penalty
else:
    score += 40  # Boost original releases

# Album matching
if apple_album.lower() == preferred_album.lower():
    score += 100  # Exact match
elif _string_similarity(apple_album, preferred_album) > 0.8:
    score += 50   # Strong fuzzy match
elif _string_similarity(apple_album, preferred_album) > 0.5:
    score += 25   # Weak fuzzy match

# Track type matching
if spotify_is_single == apple_is_single:
    score += 30   # Track count type match

if spotify_is_single and apple_is_single:
    score += 20   # Both singles
```

### Logging

When multiple versions exist, the system logs:
- All available albums and track counts
- Scores for each version
- Match reasons (exact_album, fuzzy_album_0.85, track_count_type_match, both_singles)
- Top 3 scored results for comparison

Example log:
```json
{
  "message": "Selected best Apple Music match",
  "isrc": "GBUM72005166",
  "album": "Rein Me In (with Olivia Dean) - Single",
  "score": 190,
  "reasons": ["original_release", "exact_album", "track_count_type_match", "both_singles"],
  "all_scores": [
    ["Rein Me In (with Olivia Dean) - Single", 190, ["original_release", "exact_album", "track_count_type_match", "both_singles"]],
    ["NOW That's What I Call Music! 122", -100, ["compilation_penalty"]],
    ["Summer Vibes 2024", -100, ["compilation_penalty"]]
  ]
}
```

## Benefits

✅ **Accurate artwork**: Matches the version user searched for
✅ **Compilation detection**: Heavily penalizes "NOW That's What I Call Music", "Greatest Hits", etc.
✅ **Original releases prioritized**: Boosts standalone releases over compilations
✅ **Singles prioritized**: When Spotify shows a single, prefer single artwork over album
✅ **Fuzzy matching**: Handles minor differences like "(Deluxe)" suffixes
✅ **Transparent**: Detailed logging shows why each version was selected
✅ **Backwards compatible**: Falls back to highest-scored result

## Testing

Test with songs that have multiple versions:
- Singles that appear on albums (e.g., "Will We Talk" - Sam Fender)
- Remastered versions (e.g., "Come Together" - The Beatles)
- Deluxe editions (e.g., any modern pop album)
- Compilation appearances

The system should now consistently select the artwork matching the Spotify version you searched for.
