//
//  QueueITApp.swift
//  QueueIT
//
//  Created by Darragh Flynn on 12/10/2025.
//

import SwiftUI
import SwiftData

@main
struct QueueITApp: App {
    // MARK: - Services & Coordinators
    // Configuration from APIConfig (reads from Info.plist, populated by .xcconfig at build time)

    @StateObject private var authService: AuthService
    @StateObject private var sessionCoordinator: SessionCoordinator

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        guard let url = URL(string: APIConfig.supabaseURL) else {
            fatalError("Invalid Supabase URL in config")
        }
        let service = AuthService(supabaseURL: url, supabaseAnonKey: APIConfig.supabaseAnonKey)
        _authService = StateObject(wrappedValue: service)
        let apiService = QueueAPIService(baseURL: APIConfig.backendURL, authService: service)
        let coordinator = SessionCoordinator(apiService: apiService)
        _sessionCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(sessionCoordinator)
                .preferredColorScheme(.dark) // Force dark mode for party aesthetic
                // Handle custom URL scheme: queueit://join?code=X
                .onOpenURL { url in
                    if let code = parseJoinCode(from: url) {
                        sessionCoordinator.pendingJoinCode = code
                    } else {
                        // Fall through to Supabase auth (magic link / OAuth)
                        Task { await authService.handleIncomingURL(url) }
                    }
                }
                // Handle Universal Links: https://queueit.app/join?code=X
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    if let code = parseJoinCode(from: url) {
                        sessionCoordinator.pendingJoinCode = code
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - URL Parsing

    /// Parses a session join code from:
    ///   • queueit://join?code=PARTY123
    ///   • https://queueit.app/join?code=PARTY123
    ///   • https://queueit.app/join/PARTY123
    ///   • https://appclip.apple.com/id?p=…&code=PARTY123
    private func parseJoinCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        // Query-param style: ?code=X
        if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
            return code
        }

        // Path style: /join/PARTY123
        let path = url.pathComponents
        if let idx = path.firstIndex(of: "join"), idx + 1 < path.count {
            return path[idx + 1]
        }

        // Custom scheme host style: queueit://join  (host = "join", no path segment)
        if url.scheme == "queueit", url.host == "join" {
            return components?.queryItems?.first(where: { $0.name == "code" })?.value
        }

        return nil
    }
}
