//
//  SessionCoordinator.swift
//  QueueIT
//
//  Coordinates session state and real-time updates
//

import Foundation
import Combine

@MainActor
class SessionCoordinator: ObservableObject {
    @Published var currentSession: CurrentSessionResponse?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let apiService: QueueAPIService
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
        currentSession?.queue ?? []
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
}

