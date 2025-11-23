//
//  AddSongRequest.swift
//  QueueIT
//
//  Request model for adding songs to queue (matches backend AddSongRequest schema)
//

import Foundation

struct AddSongRequest: Codable {
    let id: String // spotify_id
    let isrc: String // isrc_identifier
    let name: String
    let artists: String // artist
    let album: String
    let durationMs: Int // durationMSs
    let imageUrl: String // URL as string
    
    enum CodingKeys: String, CodingKey {
        case id
        case isrc
        case name
        case artists
        case album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
    }
    
    /// Create an AddSongRequest from a Track search result
    init(from track: Track) {
        self.id = track.id
        self.isrc = track.isrc ?? ""
        self.name = track.name
        self.artists = track.artists
        self.album = track.album
        self.durationMs = track.durationMs
        self.imageUrl = track.imageUrl?.absoluteString ?? ""
    }
}


