//
//  Track.swift
//  QueueIT
//
//  Created by Assistant on 13/10/2025.
//

import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: String
    let isrc: String? // ISRC can be missing from Spotify search results
    let name: String
    let artists: String
    let album: String
    let durationMs: Int
    let imageUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case isrc
        case name
        case artists
        case album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
    }
    
    /// Formatted duration as "MM:SS"
    var durationFormatted: String {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SearchResults: Decodable {
    let tracks: [Track]
}


