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
    let hostProvider: String? // 'apple' or 'spotify'
    
    enum CodingKeys: String, CodingKey {
        case id
        case joinCode = "join_code"
        case createdAt = "created_at"
        case host
        case hostProvider = "host_provider"
    }
}

// MARK: - QueuedSongResponse
struct QueuedSongResponse: Identifiable, Hashable {
    let id: UUID
    let status: String
    let addedAt: Date
    var votes: Int
    let song: Track
    let addedBy: User

    /// When this song last moved into its current vote count (set by DB trigger).
    var lastEnteredTierAt: Date? = nil
    /// True = entered tier by gaining a vote (sorts to bottom of tier).
    /// False = entered by losing a vote (sorts to top of tier).
    var enteredTierByGain: Bool = true

    var isPending: Bool {
        status == "pending"
    }

    func withOptimisticVotes(_ newVotes: Int) -> QueuedSongResponse {
        var copy = self
        copy.votes = newVotes
        return copy
    }
}

// Custom Codable conformance in an extension so the compiler still generates
// the memberwise initializer on the struct (needed for optimistic pending songs).
extension QueuedSongResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case addedAt = "added_at"
        case votes
        case song
        case addedBy = "added_by"
        case lastEnteredTierAt = "last_entered_tier_at"
        case enteredTierByGain = "entered_tier_by_gain"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        votes = try container.decode(Int.self, forKey: .votes)
        song = try container.decode(Track.self, forKey: .song)
        addedBy = try container.decode(User.self, forKey: .addedBy)
        lastEnteredTierAt = try container.decodeIfPresent(Date.self, forKey: .lastEnteredTierAt)
        // Default to true (gainer) when field is absent — safe for older API responses
        enteredTierByGain = try container.decodeIfPresent(Bool.self, forKey: .enteredTierByGain) ?? true
    }
}

// MARK: - CurrentSessionResponse (main session state)
struct CurrentSessionResponse: Codable {
    let session: SessionBase
    var currentSong: QueuedSongResponse?
    var queue: [QueuedSongResponse]
    /// The requesting user's votes in this session: queued_song_id → vote_value (1 or -1).
    /// Empty dict when the user has no votes. Decoded from `my_votes` in the API response.
    var myVotes: [UUID: Int]
    // Crowdsourced skip fields
    var skipRequestCount: Int
    var participantCount: Int
    var userRequestedSkip: Bool

    init(
        session: SessionBase,
        currentSong: QueuedSongResponse?,
        queue: [QueuedSongResponse],
        myVotes: [UUID: Int] = [:],
        skipRequestCount: Int = 0,
        participantCount: Int = 1,
        userRequestedSkip: Bool = false
    ) {
        self.session = session
        self.currentSong = currentSong
        self.queue = queue
        self.myVotes = myVotes
        self.skipRequestCount = skipRequestCount
        self.participantCount = participantCount
        self.userRequestedSkip = userRequestedSkip
    }
    
    func withUpdatedVotes(for songId: UUID, votes: Int) -> CurrentSessionResponse {
        var copy = self
        
        // Update current song if it matches
        if copy.currentSong?.id == songId {
            copy.currentSong = copy.currentSong?.withOptimisticVotes(votes)
        }
        
        // Update queue item if it matches
        copy.queue = copy.queue.map { item in
            if item.id == songId {
                return item.withOptimisticVotes(votes)
            }
            return item
        }
        
        return copy
    }
    
    enum CodingKeys: String, CodingKey {
        case session
        case currentSong = "current_song"
        case queue
        case myVotes = "my_votes"
        case skipRequestCount = "skip_request_count"
        case participantCount = "participant_count"
        case userRequestedSkip = "user_requested_skip"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(SessionBase.self, forKey: .session)
        currentSong = try container.decodeIfPresent(QueuedSongResponse.self, forKey: .currentSong)
        queue = try container.decode([QueuedSongResponse].self, forKey: .queue)
        // my_votes arrives as {"<uuid-string>": 1, ...}; map string keys to UUID, drop malformed entries.
        let rawVotes = try container.decodeIfPresent([String: Int].self, forKey: .myVotes) ?? [:]
        myVotes = Dictionary(uniqueKeysWithValues: rawVotes.compactMap { key, value in
            guard let uuid = UUID(uuidString: key) else { return nil }
            return (uuid, value)
        })
        skipRequestCount = try container.decodeIfPresent(Int.self, forKey: .skipRequestCount) ?? 0
        participantCount = try container.decodeIfPresent(Int.self, forKey: .participantCount) ?? 1
        userRequestedSkip = try container.decodeIfPresent(Bool.self, forKey: .userRequestedSkip) ?? false
    }
}

// MARK: - Skip Response

struct SkipResponse: Codable {
    let ok: Bool
    let skipRequestCount: Int
    let participantCount: Int
    let skipped: Bool

    enum CodingKeys: String, CodingKey {
        case ok
        case skipRequestCount = "skip_request_count"
        case participantCount = "participant_count"
        case skipped
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


