//
//  Track.swift
//  QueueIT
//
//  Created by Assistant on 13/10/2025.
//

import Foundation

struct Track: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let artists: [String]
    let album: String
    let durationMs: Int
    let imageUrl: URL?
    let previewUrl: URL?
    let externalUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artists
        case album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
        case previewUrl = "preview_url"
        case externalUrl = "external_url"
    }
}

struct SearchResults: Decodable {
    let tracks: [Track]
}


