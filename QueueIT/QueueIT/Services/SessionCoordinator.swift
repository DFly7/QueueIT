//
//  SessionCoordinator.swift
//  QueueIT
//
//  Coordinates session state and real-time updates
//

import Foundation
import Combine
import SwiftUI
#if !APPCLIP
import MusicKit
#endif

@MainActor
class SessionCoordinator: ObservableObject {
    @Published var currentSession: CurrentSessionResponse? {
        didSet {
            handleSessionChange(oldValue: oldValue, newValue: currentSession)
        }
    }
    @Published var isLoading: Bool = false
    @Published var error: String?
    /// Set to true when the host deletes their account (or ends the session) while the current
    /// user is a guest. WelcomeView observes this to show a "host ended session" toast.
    @Published var hostEndedSession: Bool = false
    
    // Optimistic UI state
    @Published var userVotes: [UUID: Int] = [:]  // queuedSongId -> user's vote (1, -1, or 0) - for button highlighting
    @Published var displayedVoteCounts: [UUID: Int] = [:]  // queuedSongId -> displayed vote count (set from session data OR optimistic updates)
    @Published var pendingSongs: [QueuedSongResponse] = []  // Songs being added
    @Published var optimisticSkip: Bool = false  // Track being skipped
    /// Set by URL/deep link handling; consumed by JoinSessionView or App Clip root view
    @Published var pendingJoinCode: String?

    // Optimistic tier metadata: set when a vote is in-flight so the within-tier
    // position is immediately correct without waiting for the server.
    // Cleared when the server confirms the vote and votesInFlight removes the song.
    private var optimisticTierMetadata: [UUID: (byGain: Bool, at: Date)] = [:]

    private var votesInFlight: Set<UUID> = []  // Songs currently being voted on - don't overwrite from server
    private var pendingVoteValues: [UUID: Int] = [:]  // Queued vote values to send after current in-flight completes
    
    public let apiService: QueueAPIService
    private var realtimeService: RealtimeService?
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

        // Sort using the full asymmetric tier key, substituting optimistic tier metadata
        // when a vote is in-flight. This avoids the two-step approach (sort + post-sort
        // edge-insertion) which produced a snap: edge-insertion ignored the full sort key
        // (lastEnteredTierAt, addedAt), so the song landed in the wrong position optimistically
        // and then snapped to the correct server position when optimisticTierMetadata cleared.
        //
        // Using optimistic metadata directly in the comparator yields a total order that
        // matches the server key (votes, byGain, timestamp, addedAt), so the transition
        // to server data on session refresh is position-stable.
        let optimistic = optimisticTierMetadata
        func effectiveTier(for song: QueuedSongResponse) -> (byGain: Bool, at: Date) {
            if let meta = optimistic[song.id] { return (meta.byGain, meta.at) }
            return (song.enteredTierByGain, song.lastEnteredTierAt ?? song.addedAt)
        }

        filtered.sort { s1, s2 in
            let v1 = displayedVoteCounts[s1.id] ?? s1.votes
            let v2 = displayedVoteCounts[s2.id] ?? s2.votes
            if v1 != v2 { return v1 > v2 }
            let (byGain1, t1) = effectiveTier(for: s1)
            let (byGain2, t2) = effectiveTier(for: s2)
            if byGain1 != byGain2 { return !byGain1 }
            if t1 != t2 { return byGain1 ? t1 < t2 : t1 > t2 }
            return s1.addedAt < s2.addedAt
        }

        // Pending songs (being added) always go at the end
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
        
        // Validate join code before API call
        if let validationError = Validator.validateJoinCode(joinCode) {
            await MainActor.run {
                self.error = validationError.localizedDescription
                HapticFeedback.error()
            }
            return
        }
        
        do {
            let session = try await apiService.createSession(joinCode: joinCode)
            currentSession = session
            populateDisplayedVoteCounts(from: session)
            populateUserVotes(from: session)
            connectRealtime()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                HapticFeedback.error()
            }
        }
    }
    
    func joinSession(joinCode: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        // Validate join code before API call
        if let validationError = Validator.validateJoinCode(joinCode) {
            await MainActor.run {
                self.error = validationError.localizedDescription
                HapticFeedback.error()
            }
            return
        }
        
        do {
            let session = try await apiService.joinSession(joinCode: joinCode)
            currentSession = session
            populateDisplayedVoteCounts(from: session)
            populateUserVotes(from: session)
            connectRealtime()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                HapticFeedback.error()
            }
        }
    }
    
    func refreshSession() async {
        guard isInSession else { return }
        
        do {
            let newSession = try await apiService.getCurrentSession()

            // If the backend flagged the last advance as a crowdsourced skip, show the
            // full bar briefly on all devices before switching songs. The flag is set
            // by the crowdsourced_skip_advance RPC and cleared by every other advance
            // path (host skip, natural song end), so no heuristic is needed.
            let songChanged = currentSession?.currentSong?.id != newSession.currentSong?.id

            if songChanged && newSession.lastSkipWasCrowdsourced {
                if var displaySession = currentSession {
                    displaySession.skipRequestCount = displaySession.participantCount
                    displaySession.userRequestedSkip = true
                    currentSession = displaySession
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }

            currentSession = newSession
            populateDisplayedVoteCounts(from: newSession)
            populateUserVotes(from: newSession)
            error = nil
        } catch {
            if case APIError.serverError(let statusCode, _) = error, statusCode == 404 {
                handleSessionVanished()
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    private func handleSessionVanished() {
        disconnectRealtime()
        #if !APPCLIP
        MusicManager.shared.stop()
        #endif
        currentSession = nil
        userVotes = [:]
        displayedVoteCounts = [:]
        optimisticTierMetadata = [:]
        pendingVoteValues = [:]
        votesInFlight = []
        pendingSongs = []
        optimisticSkip = false
        error = nil
        hostEndedSession = true
    }

    private func populateUserVotes(from session: CurrentSessionResponse) {
        // Build the set of song IDs still present in the session so stale entries can
        // be pruned. Always union with votesInFlight so an in-flight vote is never removed
        // mid-submit even if the session snapshot doesn't include it yet.
        var validIds: Set<UUID> = Set(session.queue.map { $0.id })
        if let currentId = session.currentSong?.id { validIds.insert(currentId) }
        validIds.formUnion(votesInFlight)

        // Merge server votes, skipping any song whose vote is still in-flight to
        // avoid overwriting the optimistic value the user already sees.
        for (songId, voteValue) in session.myVotes where !votesInFlight.contains(songId) {
            userVotes[songId] = voteValue
        }

        // Prune votes for songs that have left the session (played, skipped, etc.)
        // while keeping in-flight votes alive until they resolve.
        userVotes = userVotes.filter { validIds.contains($0.key) }
    }

    private func populateDisplayedVoteCounts(from session: CurrentSessionResponse) {
        // Populate displayed vote counts from session data.
        // Skip songs with a vote in-flight to avoid overwriting the optimistic count.
        // For songs that are NOT in-flight, also clear their optimistic tier metadata —
        // the server response now has the correct enteredTierByGain / lastEnteredTierAt
        // so there is no longer a gap that would cause a wrong-position snap.
        if let currentSong = session.currentSong {
            if !votesInFlight.contains(currentSong.id) {
                displayedVoteCounts[currentSong.id] = currentSong.votes
                optimisticTierMetadata.removeValue(forKey: currentSong.id)
            }
        }
        for queuedSong in session.queue {
            if !votesInFlight.contains(queuedSong.id) {
                displayedVoteCounts[queuedSong.id] = queuedSong.votes
                optimisticTierMetadata.removeValue(forKey: queuedSong.id)
            }
        }
    }
    
    func leaveSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await apiService.leaveSession()
            disconnectRealtime()
            #if !APPCLIP
            if isHost {
                MusicManager.shared.stop()
            }
            #endif
            // Reset all optimistic state
            currentSession = nil
            userVotes = [:]
            displayedVoteCounts = [:]
            optimisticTierMetadata = [:]
            pendingVoteValues = [:]
            votesInFlight = []
            pendingSongs = []
            optimisticSkip = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Realtime Management

    private func connectRealtime() {
        guard let sessionId = currentSession?.session.id else { return }

        if realtimeService == nil {
            realtimeService = RealtimeService(authService: apiService.authService)
            realtimeService?.setSessionCoordinator(self)
        }

        Task {
            await realtimeService?.subscribe(to: sessionId)
        }
    }

    private func disconnectRealtime() {
        Task {
            await realtimeService?.unsubscribe()
        }
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
        
        // If clicking the same vote button, remove the vote
        let targetValue = (previousUserVote == value) ? 0 : value
        
        // Update UI immediately (optimistic)
        userVotes[songId] = targetValue
        
        // Calculate what the displayed count should be based on vote direction
        // We use a simple model: server_base + user_vote_effect
        // where user_vote_effect is +1 for upvote, -1 for downvote, 0 for no vote
        
        // If there's already a vote in-flight, just queue our new value and update UI
        if votesInFlight.contains(songId) {
            pendingVoteValues[songId] = targetValue
            if let currentDisplayed = displayedVoteCounts[songId] {
                let delta = targetValue - previousUserVote
                if delta != 0 {
                    optimisticTierMetadata[songId] = (byGain: delta > 0, at: Date())
                }
                withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                    displayedVoteCounts[songId] = currentDisplayed + delta
                }
            }
            return
        }
        
        // No vote in-flight, we'll send this one
        await sendVote(songId: songId, value: targetValue, previousUserVote: previousUserVote, originalVotes: queuedSong.votes)
    }
    
    private func sendVote(songId: UUID, value: Int, previousUserVote: Int, originalVotes: Int) async {
        // Mark vote as in-flight
        votesInFlight.insert(songId)

        // Calculate optimistic display and tier metadata
        let baseVotes = displayedVoteCounts[songId] ?? originalVotes
        let delta = value - previousUserVote
        let optimisticCount = baseVotes + delta
        if delta != 0 {
            // Set tier metadata immediately so within-tier position is correct
            // without waiting for the server (avoids snap when song crosses tiers)
            optimisticTierMetadata[songId] = (byGain: delta > 0, at: Date())
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
            displayedVoteCounts[songId] = optimisticCount
        }

        // Send to server
        do {
            let response: VoteResponse
            if value == 0 {
                // Remove vote
                response = try await apiService.removeVote(queuedSongId: songId)
            } else {
                // Add or change vote
                response = try await apiService.vote(queuedSongId: songId, voteValue: value)
            }

            // Update with server's authoritative total
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                displayedVoteCounts[songId] = response.totalVotes
            }
        } catch {
            // On error, we don't rollback userVotes since the user's intent is clear
            // Just show whatever the server last told us (or keep optimistic)
            self.error = error.localizedDescription
        }

        // Remove from in-flight. Do NOT clear optimisticTierMetadata here —
        // the session refresh (GET /sessions/current) hasn't arrived yet, so
        // the server's enteredTierByGain is still stale in currentSession.
        // populateDisplayedVoteCounts clears it once the fresh session data lands.
        votesInFlight.remove(songId)

        // Check if there's a pending vote to send
        if let pendingValue = pendingVoteValues.removeValue(forKey: songId) {
            // Only send if the pending value is different from what we just sent
            if pendingValue != value {
                await sendVote(songId: songId, value: pendingValue, previousUserVote: value, originalVotes: originalVotes)
            }
        }
    }
    
    // MARK: - Crowdsourced Skip

    func requestSkip() async {
        do {
            let response = try await apiService.requestSkip()

            // Always apply the updated counts so the UI reflects the tap immediately.
            // When the threshold was met the backend returns skip_request_count == 0
            // (already cleared), so we show participantCount/participantCount briefly
            // before refreshing to give the user visible feedback that the vote landed.
            if var session = currentSession {
                let displayCount = response.skipped ? response.participantCount : response.skipRequestCount
                session.skipRequestCount = displayCount
                session.participantCount = response.participantCount
                session.userRequestedSkip = true
                currentSession = session
            }

            if response.skipped {
                // Short pause so the full bar is visible before the song changes
                try? await Task.sleep(nanoseconds: 700_000_000)
                await refreshSession()
            }
        } catch {
            self.error = error.localizedDescription
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

    #if !APPCLIP
    private func handleSessionChange(oldValue: CurrentSessionResponse?, newValue: CurrentSessionResponse?) {
        // Only host should play music
        guard isHost else { return }
        
        let oldSongId = oldValue?.currentSong?.id
        let newSongId = newValue?.currentSong?.id
        
        print("🔄 SessionCoordinator: Session changed - oldSong: \(oldValue?.currentSong?.song.name ?? "none"), newSong: \(newValue?.currentSong?.song.name ?? "none")")
        
        if oldSongId != newSongId {
            if let newSong = newValue?.currentSong {
                print("▶️ SessionCoordinator: Playing new track: \(newSong.song.name)")
                Task {
                    await playTrack(newSong.song)
                }
            } else {
                print("⏹️ SessionCoordinator: No current song, stopping playback")
                MusicManager.shared.stop()
            }
        }
    }
    
    private func playTrack(_ track: Track) async {
        print("🎵 SessionCoordinator: playTrack called for '\(track.name)' by \(track.artists)")
        
        if !MusicManager.shared.isAuthorized {
            print("🔐 SessionCoordinator: Requesting music access...")
            await MusicManager.shared.requestAccess()
        }
        
        guard MusicManager.shared.canPlayMusic else {
            print("❌ SessionCoordinator: Cannot play music - not authorized or no subscription")
            return
        }
        
        // Define the callback once to avoid duplication
        let onFinishedCallback: () -> Void = { [weak self] in
            Task { @MainActor in
                print("🎵 SessionCoordinator: onFinishedCallback triggered")
                await self?.handleSongFinished()
            }
        }
        
        // If it's an Apple Music track, play directly by catalog ID (no search needed!)
        if track.source == .appleMusic {
            print("🎵 SessionCoordinator: Playing Apple Music track by catalog ID: \(track.id)")
            await MusicManager.shared.playByCatalogID(track.id, onFinished: onFinishedCallback)
        } else {
            // Fallback: Search by artist + song name for Spotify tracks
            print("🔍 SessionCoordinator: Searching Apple Music for Spotify track: \(track.name)")
            let query = "\(track.name) \(track.artists)"
            if let appleMusicSong = await MusicManager.shared.searchForSong(query: query) {
                await MusicManager.shared.play(song: appleMusicSong, onFinished: onFinishedCallback)
            } else {
                print("❌ SessionCoordinator: Could not find song on Apple Music: \(query)")
            }
        }
    }
    
    private func handleSongFinished() async {
        guard isHost else { return }
        
        print("🎵 SessionCoordinator: Song finished, advancing queue...")
        
        do {
            try await apiService.songFinished()
            print("✅ SessionCoordinator: Backend acknowledged song finished")
            // Refresh to get the next song
            await refreshSession()
            print("✅ SessionCoordinator: Session refreshed, currentSong: \(currentSession?.currentSong?.song.name ?? "none")")
        } catch {
            print("❌ SessionCoordinator: Failed to mark song as finished: \(error)")
            // Retry once after a short delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            do {
                try await apiService.songFinished()
                await refreshSession()
                print("✅ SessionCoordinator: Retry succeeded")
            } catch {
                print("❌ SessionCoordinator: Retry also failed: \(error)")
            }
        }
    }
    #else
    // App Clip: no-op stub required because currentSession didSet references this method
    private func handleSessionChange(oldValue: CurrentSessionResponse?, newValue: CurrentSessionResponse?) {}
    #endif
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

