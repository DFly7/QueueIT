//
//  RealtimeService.swift
//  QueueIT
//
//  Supabase Realtime subscription service for multi-user vote and queue sync
//

import Combine
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
    /// Debounce task: cancels any pending refresh when a new event arrives so
    /// bursts of simultaneous realtime events (e.g. bulk DELETE on skip_requests)
    /// coalesce into a single refreshSession() call on the main actor.
    private var pendingRefreshTask: Task<Void, Never>?
    
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
            self?.handleChange(source: "votes")
        }
        .store(in: &subscriptions)
        
        // Listen to queued_songs table changes for this session
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "queued_songs",
            filter: "session_id=eq.\(sessionId.uuidString)"
        ) { [weak self] _ in
            self?.handleChange(source: "queued_songs")
        }
        .store(in: &subscriptions)
        
        // Listen to session table changes (e.g., current_song update, lock status)
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "sessions",
            filter: "id=eq.\(sessionId.uuidString)"
        ) { [weak self] _ in
            self?.handleChange(source: "sessions")
        }
        .store(in: &subscriptions)

        // Listen to skip_requests changes so all participants see live skip counts.
        // Requires skip_requests to be in the supabase_realtime publication
        // (see migration 20260317_skip_requests_realtime.sql).
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "skip_requests",
            filter: "session_id=eq.\(sessionId.uuidString)"
        ) { [weak self] _ in
            self?.handleChange(source: "skip_requests")
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
        
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
        subscriptions.removeAll()
        
        if let channel = channel {
            await authService.client.realtimeV2.removeChannel(channel)
            self.channel = nil
        }
        
        isConnected = false
        print("🔴 RealtimeService: Unsubscribed")
    }
    
    // MARK: - Change Handler

    /// Entry point called from nonisolated Postgres-change closures.
    /// Uses `await` to cross into the main actor — the Swift 6-safe way to
    /// call an `@MainActor` method from a nonisolated context.
    nonisolated private func handleChange(source: String) {
        Task { [weak self] in
            await self?.scheduleRefresh(source: source)
        }
    }

    /// Cancels any pending refresh and schedules a new one after a short debounce
    /// window. Rapid bursts of events (e.g. bulk DELETE on skip_requests) coalesce
    /// into a single refreshSession() call.
    /// Captures `coordinator` directly so no `self` reference leaks into the Task.
    @MainActor
    private func scheduleRefresh(source: String) {
        pendingRefreshTask?.cancel()
        let coordinator = sessionCoordinator
        pendingRefreshTask = Task {
            guard let coordinator else { return }
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            guard !Task.isCancelled else { return }
            print("🔄 RealtimeService: refreshing session (triggered by \(source))")
            await coordinator.refreshSession()
        }
    }
}
