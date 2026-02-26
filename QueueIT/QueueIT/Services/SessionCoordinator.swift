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
        return q.filter { $0.id != currentId && $0.status == "queued" }
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
            currentSession = try await apiService.createSession(joinCode: joinCode)
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
            currentSession = try await apiService.joinSession(joinCode: joinCode)
            connectWebSocket()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func refreshSession() async {
        guard isInSession else { return }
        
        do {
            currentSession = try await apiService.getCurrentSession()
            error = nil
        } catch {
            self.error = error.localizedDescription
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
            currentSession = nil
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
    
    func addSong(track: Track) async {
        guard isInSession else {
            error = "Not in an active session"
            return
        }
        
        do {
            let request = AddSongRequest(from: track)
            _ = try await apiService.addSong(request)
            // Refresh to get updated queue
            await refreshSession()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func vote(on queuedSong: QueuedSongResponse, value: Int) async {
        do {
            _ = try await apiService.vote(queuedSongId: queuedSong.id, voteValue: value)
            // Optimistic update or refresh
            await refreshSession()
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
        
        do {
            try await apiService.controlSession(skipCurrentTrack: true)
            await refreshSession()
        } catch {
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

