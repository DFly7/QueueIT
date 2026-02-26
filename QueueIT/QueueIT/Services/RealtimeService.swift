//
//  RealtimeService.swift
//  QueueIT
//
//  Supabase Realtime subscription service for multi-user vote and queue sync
//

import Foundation
import Supabase
import Realtime

@MainActor
class RealtimeService: ObservableObject {
    @Published var isConnected: Bool = false
    
    private var channel: RealtimeChannelV2?
    private var subscriptions: Set<RealtimeSubscription> = []
    private let authService: AuthService
    private weak var sessionCoordinator: SessionCoordinator?
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func setSessionCoordinator(_ coordinator: SessionCoordinator) {
        self.sessionCoordinator = coordinator
    }
    
    // MARK: - Subscribe to Session Changes
    
    func subscribe(to sessionId: UUID) async {
        await unsubscribe()
        
        print("🟢 RealtimeService: Subscribing to session \(sessionId)")
        
        let client = authService.client
        
        let channelName = "session_\(sessionId.uuidString)"
        channel = client.realtimeV2.channel(channelName)
        
        guard let channel = channel else {
            print("❌ RealtimeService: Failed to create channel")
            return
        }
        
        // Monitor connection status
        channel.onStatusChange { [weak self] status in
            Task { @MainActor in
                switch status {
                case .subscribed:
                    print("✅ RealtimeService: Channel subscribed")
                    self?.isConnected = true
                case .subscribing:
                    print("🔄 RealtimeService: Channel subscribing...")
                case .unsubscribed:
                    print("🔌 RealtimeService: Channel unsubscribed")
                    self?.isConnected = false
                case .unsubscribing:
                    print("🔄 RealtimeService: Channel unsubscribing...")
                @unknown default:
                    print("❓ RealtimeService: Unknown channel status")
                }
            }
        }
        .store(in: &subscriptions)
        
        // Listen to votes table changes (INSERT, UPDATE, DELETE)
        // Votes are linked to queued_songs via queued_song_id, so we need to listen for all vote changes
        // and filter/refresh based on session context
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "votes"
        ) { [weak self] _ in
            Task { @MainActor in
                print("📬 RealtimeService: Votes changed")
                await self?.handleChange()
            }
        }
        .store(in: &subscriptions)
        
        // Listen to queued_songs table changes for this session
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "queued_songs",
            filter: "session_id=eq.\(sessionId.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                print("📬 RealtimeService: Queue changed")
                await self?.handleChange()
            }
        }
        .store(in: &subscriptions)
        
        // Listen to session table changes (e.g., current_song update, lock status)
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "sessions",
            filter: "id=eq.\(sessionId.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                print("📬 RealtimeService: Session changed")
                await self?.handleChange()
            }
        }
        .store(in: &subscriptions)
        
        // Subscribe to the channel
        do {
            try await channel.subscribeWithError()
            print("✅ RealtimeService: Successfully subscribed to channel")
        } catch {
            print("❌ RealtimeService: Failed to subscribe - \(error)")
        }
    }
    
    func unsubscribe() async {
        print("🔴 RealtimeService: Unsubscribing...")
        
        subscriptions.removeAll()
        
        if let channel = channel {
            await authService.client.realtimeV2.removeChannel(channel)
            self.channel = nil
        }
        
        isConnected = false
        print("🔴 RealtimeService: Unsubscribed")
    }
    
    // MARK: - Change Handler
    
    private func handleChange() async {
        // When any tracked table changes, refresh the session
        // The optimistic UI handles the user's own actions,
        // this syncs changes from other users
        
        guard let coordinator = sessionCoordinator else { return }
        
        // Small delay to allow database to settle
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        await coordinator.refreshSession()
    }
}
