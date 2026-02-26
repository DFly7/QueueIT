//
//  SessionCoordinator.swift
//  QueueIT
//
//  Coordinates session state and real-time updates
//

import Foundation
import Combine
import MusicKit

@MainActor
class SessionCoordinator: ObservableObject {
    @Published var currentSession: CurrentSessionResponse? {
        didSet {
            handleSessionChange(oldValue: oldValue, newValue: currentSession)
        }
    }
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // Optimistic UI state
    @Published var userVotes: [UUID: Int] = [:]  // queuedSongId -> user's vote (1, -1, or 0) - for button highlighting
    @Published var displayedVoteCounts: [UUID: Int] = [:]  // queuedSongId -> displayed vote count (set from session data OR optimistic updates)
    @Published var pendingSongs: [QueuedSongResponse] = []  // Songs being added
    @Published var optimisticSkip: Bool = false  // Track being skipped
    
    private var votesInFlight: Set<UUID> = []  // Songs currently being voted on - don't overwrite from server
    private var pendingVoteValues: [UUID: Int] = [:]  // Queued vote values to send after current in-flight completes
    
    public let apiService: QueueAPIService
    private var webSocketService: WebSocketService?
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties for easier access
    var isInSession: Bool {
        currentSession != nil
    }
    
    var isHost: Bool {
        guard let session = currentSession,
              let userId = apiService.authService.currentUser?.id else {
            return false
        }
        return session.session.host.id == userId
    }
    
    var nowPlaying: QueuedSongResponse? {
        currentSession?.currentSong
    }
    
    var queue: [QueuedSongResponse] {
        let q = currentSession?.queue ?? []
        let currentId = currentSession?.currentSong?.id
        // Only show songs that are "queued" (not played or skipped)
        var filtered = q.filter { $0.id != currentId && $0.status == "queued" }
        
        // Sort by displayed vote counts (descending), then by addedAt (ascending) for ties
        filtered.sort { song1, song2 in
            let votes1 = displayedVoteCounts[song1.id] ?? song1.votes
            let votes2 = displayedVoteCounts[song2.id] ?? song2.votes
            if votes1 != votes2 {
                return votes1 > votes2  // Higher votes first
            }
            return song1.addedAt < song2.addedAt  // Earlier added first for ties
        }
        
        // Add pending songs at the end (they have 0 votes and are newest)
        let newPending = pendingSongs.filter { pending in
            !filtered.contains(where: { $0.song.id == pending.song.id })
        }
        filtered.append(contentsOf: newPending)
        
        return filtered
    }
    
    var nowPlayingWithOptimisticVotes: QueuedSongResponse? {
        guard let nowPlaying = currentSession?.currentSong else { return nil }
        if optimisticSkip { return nil }
        return nowPlaying
    }
    
    func getUserVote(for songId: UUID) -> Int {
        return userVotes[songId] ?? 0
    }
    
    func getDisplayedVoteCount(for songId: UUID) -> Int {
        // Read from the displayedVoteCounts dictionary - this is always our source of truth for the UI
        return displayedVoteCounts[songId] ?? 0
    }
    
    init(apiService: QueueAPIService) {
        self.apiService = apiService
    }
    
    // MARK: - Session Management
    
    func createSession(joinCode: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let session = try await apiService.createSession(joinCode: joinCode)
            currentSession = session
            populateDisplayedVoteCounts(from: session)
            connectWebSocket()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func joinSession(joinCode: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let session = try await apiService.joinSession(joinCode: joinCode)
            currentSession = session
            populateDisplayedVoteCounts(from: session)
            connectWebSocket()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func refreshSession() async {
        guard isInSession else { return }
        
        do {
            let session = try await apiService.getCurrentSession()
            currentSession = session
            populateDisplayedVoteCounts(from: session)
            // Note: we keep userVotes so button highlights persist
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func populateDisplayedVoteCounts(from session: CurrentSessionResponse) {
        // Populate displayed vote counts from session data
        // Skip any songs that have a vote in-flight to avoid race conditions
        if let currentSong = session.currentSong {
            if !votesInFlight.contains(currentSong.id) {
                displayedVoteCounts[currentSong.id] = currentSong.votes
            }
        }
        for queuedSong in session.queue {
            if !votesInFlight.contains(queuedSong.id) {
                displayedVoteCounts[queuedSong.id] = queuedSong.votes
            }
        }
    }
    
    func leaveSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await apiService.leaveSession()
            disconnectWebSocket()
            if isHost {
                MusicManager.shared.stop()
            }
            // Reset all optimistic state
            currentSession = nil
            userVotes = [:]
            displayedVoteCounts = [:]
            pendingVoteValues = [:]
            votesInFlight = []
            pendingSongs = []
            optimisticSkip = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - WebSocket Management
    
    private func connectWebSocket() {
        guard let sessionId = currentSession?.session.id else { return }
        
        // Initialize WebSocket service if needed
        if webSocketService == nil {
            webSocketService = WebSocketService(
                baseURL: URL(string: "http://localhost:8000")!, // TODO: Use config
                authService: apiService.authService,
                sessionCoordinator: self
            )
        }
        
        webSocketService?.connect(sessionId: sessionId)
    }
    
    private func disconnectWebSocket() {
        webSocketService?.disconnect()
    }

    // MARK: - Queue Management
    
    func addSong(track: Track) async -> Bool {
        guard isInSession else {
            error = "Not in an active session"
            return false
        }
        
        // Create optimistic pending song
        let pendingSong = QueuedSongResponse(
            id: UUID(), // Temporary ID
            status: "pending",
            addedAt: Date(),
            votes: 0,
            song: track,
            addedBy: User(
                id: apiService.authService.currentUser?.id ?? UUID(),
                username: apiService.authService.currentUser?.username ?? "You"
            )
        )
        
        // Add to pending songs immediately
        pendingSongs.append(pendingSong)
        
        do {
            let request = AddSongRequest(from: track)
            _ = try await apiService.addSong(request)
            
            // Remove from pending and refresh to get real data
            pendingSongs.removeAll { $0.song.id == track.id }
            await refreshSession()
            return true
        } catch {
            // Remove from pending on failure
            pendingSongs.removeAll { $0.song.id == track.id }
            self.error = error.localizedDescription
            return false
        }
    }
    
    func vote(on queuedSong: QueuedSongResponse, value: Int) async {
        let songId = queuedSong.id
        let previousUserVote = userVotes[songId] ?? 0
        
        // If same vote as before, no-op (backend uses upsert, so duplicate votes are ignored)
        guard previousUserVote != value else { return }
        
        // Update UI immediately (optimistic) - always do this regardless of in-flight status
        userVotes[songId] = value
        
        // Calculate what the displayed count should be based on vote direction
        // We use a simple model: server_base + user_vote_effect
        // where user_vote_effect is +1 for upvote, -1 for downvote
        // This avoids accumulation errors from rapid voting
        
        // If there's already a vote in-flight, just queue our new value and update UI
        if votesInFlight.contains(songId) {
            pendingVoteValues[songId] = value
            // Recalculate display: we don't know server base, but we know our vote changed
            // Just show the effect of our current vote direction
            if let currentDisplayed = displayedVoteCounts[songId] {
                let delta = value - previousUserVote
                displayedVoteCounts[songId] = currentDisplayed + delta
            }
            return
        }
        
        // No vote in-flight, we'll send this one
        await sendVote(songId: songId, value: value, previousUserVote: previousUserVote, originalVotes: queuedSong.votes)
    }
    
    private func sendVote(songId: UUID, value: Int, previousUserVote: Int, originalVotes: Int) async {
        // Mark vote as in-flight
        votesInFlight.insert(songId)
        
        // Calculate optimistic display
        let baseVotes = displayedVoteCounts[songId] ?? originalVotes
        let delta = value - previousUserVote
        let optimisticCount = baseVotes + delta
        displayedVoteCounts[songId] = optimisticCount
        
        // Send to server
        do {
            let response = try await apiService.vote(queuedSongId: songId, voteValue: value)
            
            // Update with server's authoritative total
            displayedVoteCounts[songId] = response.totalVotes
        } catch {
            // On error, we don't rollback userVotes since the user's intent is clear
            // Just show whatever the server last told us (or keep optimistic)
            self.error = error.localizedDescription
        }
        
        // Remove from in-flight
        votesInFlight.remove(songId)
        
        // Check if there's a pending vote to send
        if let pendingValue = pendingVoteValues.removeValue(forKey: songId) {
            let currentUserVote = userVotes[songId] ?? 0
            // Only send if the pending value is different from what we just sent
            if pendingValue != value {
                await sendVote(songId: songId, value: pendingValue, previousUserVote: value, originalVotes: originalVotes)
            }
        }
    }
    
    // MARK: - Host Controls
    
    func skipCurrentTrack() async {
        guard isHost else {
            error = "Only the host can skip tracks"
            return
        }
        
        // Optimistically hide the current track
        optimisticSkip = true
        
        do {
            try await apiService.controlSession(skipCurrentTrack: true)
            optimisticSkip = false
            await refreshSession()
        } catch {
            optimisticSkip = false
            self.error = error.localizedDescription
        }
    }
    
    func toggleLock(locked: Bool) async {
        guard isHost else {
            error = "Only the host can lock the queue"
            return
        }
        
        do {
            try await apiService.controlSession(isLocked: locked)
            await refreshSession()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Music Playback Handling
    
    private func handleSessionChange(oldValue: CurrentSessionResponse?, newValue: CurrentSessionResponse?) {
        // Only host should play music
        guard isHost else { return }
        
        let oldSongId = oldValue?.currentSong?.id
        let newSongId = newValue?.currentSong?.id
        
        if oldSongId != newSongId {
            if let newSong = newValue?.currentSong {
                Task {
                    await playTrack(newSong.song)
                }
            } else {
                MusicManager.shared.stop()
            }
        }
    }
    
    private func playTrack(_ track: Track) async {
        if !MusicManager.shared.isAuthorized {
            await MusicManager.shared.requestAccess()
        }
        
        guard MusicManager.shared.canPlayMusic else {
            print("Cannot play music: Not authorized or no subscription")
            return
        }
        
        // If it's an Apple Music track, play directly by catalog ID (no search needed!)
        if track.source == .appleMusic {
            print("🎵 Playing Apple Music track by catalog ID: \(track.id)")
            await MusicManager.shared.playByCatalogID(track.id) { [weak self] in
                Task { @MainActor in
                    await self?.handleSongFinished()
                }
            }
        } else {
            // Fallback: Search by artist + song name for Spotify tracks
            print("🔍 Searching Apple Music for Spotify track: \(track.name)")
            let query = "\(track.name) \(track.artists)"
            if let appleMusicSong = await MusicManager.shared.searchForSong(query: query) {
                await MusicManager.shared.play(song: appleMusicSong) { [weak self] in
                    Task { @MainActor in
                        await self?.handleSongFinished()
                    }
                }
            } else {
                print("❌ Could not find song on Apple Music: \(query)")
            }
        }
    }
    
    private func handleSongFinished() async {
        guard isHost else { return }
        
        do {
            try await apiService.songFinished()
            // Refresh to get the next song
            await refreshSession()
        } catch {
            print("Failed to mark song as finished: \(error)")
        }
    }
}


extension SessionCoordinator {
    @MainActor
    // 1. Change default to nil
    static func mock(auth: AuthService? = nil) -> SessionCoordinator {
        
        // 2. Unwrap or use .mock inside the function body
        // This is safe because the function body is @MainActor
        let actualAuth = auth ?? AuthService.mock
        
        let api = QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: actualAuth
        )
        return SessionCoordinator(apiService: api)
    }
}

