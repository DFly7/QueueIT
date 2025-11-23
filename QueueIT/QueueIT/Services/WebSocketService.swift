//
//  WebSocketService.swift
//  QueueIT
//
//  WebSocket client for real-time queue/vote/now-playing updates
//

import Foundation
import Combine

@MainActor
class WebSocketService: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let sessionCoordinator: SessionCoordinator
    private let authService: AuthService
    private let baseURL: URL
    
    init(baseURL: URL, authService: AuthService, sessionCoordinator: SessionCoordinator) {
        self.baseURL = baseURL
        self.authService = authService
        self.sessionCoordinator = sessionCoordinator
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect(sessionId: UUID) {
        guard let token = authService.accessToken else {
            print("❌ Cannot connect WebSocket: no auth token")
            return
        }
        
        // Convert http:// to ws:// or https:// to wss://
        var wsURLString = baseURL.absoluteString
        wsURLString = wsURLString.replacingOccurrences(of: "http://", with: "ws://")
        wsURLString = wsURLString.replacingOccurrences(of: "https://", with: "wss://")
        
        guard let wsURL = URL(string: "\(wsURLString)/api/v1/sessions/\(sessionId.uuidString)/realtime") else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        
        print("✅ WebSocket connected to session: \(sessionId)")
        
        // Start listening for messages
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        print("🔌 WebSocket disconnected")
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleMessage(message)
                    // Continue listening
                    self.receiveMessage()
                }
                
            case .failure(let error):
                print("❌ WebSocket error: \(error)")
                Task { @MainActor in
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            parseEvent(from: data)
            
        case .data(let data):
            parseEvent(from: data)
            
        @unknown default:
            break
        }
    }
    
    private func parseEvent(from data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let eventType = json?["event"] as? String else { return }
            
            print("📬 WebSocket event: \(eventType)")
            
            switch eventType {
            case "queue.updated":
                // Refresh session to get updated queue
                Task {
                    await sessionCoordinator.refreshSession()
                }
                
            case "votes.updated":
                // Refresh session to get updated votes
                Task {
                    await sessionCoordinator.refreshSession()
                }
                
            case "now_playing.updated":
                // Refresh session to get updated now playing
                Task {
                    await sessionCoordinator.refreshSession()
                }
                
            case "session.updated":
                // Refresh entire session state
                Task {
                    await sessionCoordinator.refreshSession()
                }
                
            default:
                print("⚠️ Unknown WebSocket event: \(eventType)")
            }
            
        } catch {
            print("❌ Failed to parse WebSocket message: \(error)")
        }
    }
}

// MARK: - WebSocket Event Models (for future use)

struct WebSocketEvent: Codable {
    let event: String
    let sessionId: UUID?
    let data: EventData?
    
    enum CodingKeys: String, CodingKey {
        case event
        case sessionId = "session_id"
        case data
    }
}

struct EventData: Codable {
    let queuedSongId: UUID?
    let totalVotes: Int?
    let queue: [QueuedSongResponse]?
    let currentSong: QueuedSongResponse?
    
    enum CodingKeys: String, CodingKey {
        case queuedSongId = "queued_song_id"
        case totalVotes = "total_votes"
        case queue
        case currentSong = "current_song"
    }
}


