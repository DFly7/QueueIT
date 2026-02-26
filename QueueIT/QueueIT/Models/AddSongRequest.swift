//
//  AddSongRequest.swift
//  QueueIT
//
//  Request model for adding songs to queue (matches backend AddSongRequest schema)
//

import Foundation

struct AddSongRequest: Codable {
    let id: String
    let isrc: String
    let name: String
    let artists: String
    let album: String
    let durationMs: Int
    let imageUrl: String
    let source: String
    
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
    
    /// Create an AddSongRequest from a Track model
    init(from track: Track) {
        self.id = track.id
        self.isrc = track.isrc ?? ""
        self.name = track.name
        self.artists = track.artists
        self.album = track.album
        self.durationMs = track.durationMs
        self.imageUrl = track.imageUrl?.absoluteString ?? ""
        self.source = track.source.rawValue
    }
}


