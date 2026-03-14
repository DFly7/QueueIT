//
//  TrackSearchProvider.swift
//  QueueIT
//
//  Abstraction layer for searching tracks from different music providers.
//

import Foundation
#if !APPCLIP
import MusicKit
#endif

protocol TrackSearchProvider {
    /// Display name used in the navigation title, e.g. "Apple Music" or "Spotify Music"
    var displayName: String { get }
    /// Whether search calls should be debounced (true for backend calls, false for client-side)
    var shouldDebounce: Bool { get }
    func search(query: String, limit: Int) async throws -> [Track]
}

// MARK: - Spotify Provider

struct SpotifyTrackSearchProvider: TrackSearchProvider {
    let apiService: QueueAPIService

    var displayName: String { "Spotify Music" }
    var shouldDebounce: Bool { true }

    func search(query: String, limit: Int) async throws -> [Track] {
        let results = try await apiService.searchTracks(query: query, limit: limit)
        return results.tracks
    }
}

// MARK: - Apple Music Provider (excluded from App Clip — no MusicManager available)

#if !APPCLIP
struct AppleMusicTrackSearchProvider: TrackSearchProvider {
    var displayName: String { "Apple Music" }
    var shouldDebounce: Bool { false }

    func search(query: String, limit: Int) async throws -> [Track] {
        let songs = await MusicManager.shared.searchCatalog(query: query, limit: limit)
        return songs.map { $0.toTrack() }
    }
}
#endif
