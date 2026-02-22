//
//  Track.swift
//  QueueIT
//
//  Created by Assistant on 13/10/2025.
//

import Foundation

enum MusicSource: String, Codable {
    case spotify = "spotify"
    case appleMusic = "apple_music"
}

struct Track: Identifiable, Codable, Hashable {
    let id: String
    let isrc: String?
    let name: String
    let artists: String
    let album: String
    let durationMs: Int
    let imageUrl: URL?
    let source: MusicSource

    enum CodingKeys: String, CodingKey {
        case id
        case isrc
        case name
        case artists
        case album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
        case source
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


