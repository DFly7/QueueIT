//
//  Session.swift
//  QueueIT
//
//  Session models matching backend API contracts
//

import Foundation

// MARK: - SessionBase (from CurrentSessionResponse)
struct SessionBase: Codable, Identifiable, Hashable {
    let id: UUID
    let joinCode: String
    let createdAt: Date
    let host: User
    
    enum CodingKeys: String, CodingKey {
        case id
        case joinCode = "join_code"
        case createdAt = "created_at"
        case host
    }
}

// MARK: - QueuedSongResponse
struct QueuedSongResponse: Codable, Identifiable, Hashable {
    let id: UUID
    let status: String
    let addedAt: Date
    let votes: Int
    let song: Track
    let addedBy: User
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case addedAt = "added_at"
        case votes
        case song
        case addedBy = "added_by"
    }
}

// MARK: - CurrentSessionResponse (main session state)
struct CurrentSessionResponse: Codable {
    let session: SessionBase
    let currentSong: QueuedSongResponse?
    let queue: [QueuedSongResponse]
    
    enum CodingKeys: String, CodingKey {
        case session
        case currentSong = "current_song"
        case queue
    }
}

// MARK: - Request Models

struct SessionCreateRequest: Codable {
    let joinCode: String
    
    enum CodingKeys: String, CodingKey {
        case joinCode = "join_code"
    }
}

struct SessionJoinRequest: Codable {
    let joinCode: String
    
    enum CodingKeys: String, CodingKey {
        case joinCode = "join_code"
    }
}

struct SessionControlRequest: Codable {
    let isLocked: Bool?
    let skipCurrentTrack: Bool?
    let pausePlayback: Bool?
    
    enum CodingKeys: String, CodingKey {
        case isLocked = "is_locked"
        case skipCurrentTrack = "skip_current_track"
        case pausePlayback = "pause_playback"
    }
}

// MARK: - Vote Models

struct VoteRequest: Codable {
    let voteValue: Int // 1 or -1
    
    enum CodingKeys: String, CodingKey {
        case voteValue = "vote_value"
    }
}

struct VoteResponse: Codable {
    let ok: Bool
    let totalVotes: Int
    
    enum CodingKeys: String, CodingKey {
        case ok
        case totalVotes = "total_votes"
    }
}


