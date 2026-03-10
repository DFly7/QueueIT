# Song Matching Logic

- [ ] **Store Metadata**: Capture ISRC, Duration, Title, Artist, and `isExplicit` from the source platform.
- [ ] **Query ISRC**: Search the destination API (Spotify/MusicKit) using the ISRC as the primary filter.
- [ ] **Filter by Duration**: Narrow results to tracks within a ±3-second window of the original length.
- [ ] **Resolve Ties**: If multiple matches exist, select the one with the closest Title or matching `isExplicit` flag.
- [ ] **Implement Fallback**: If ISRC returns zero results, trigger a fuzzy text search using Artist + Title.
- [ ] **Handle Storefronts**: For Apple Music, ensure the query uses the user's specific region/country code.
