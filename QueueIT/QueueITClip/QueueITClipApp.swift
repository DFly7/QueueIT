//
//  QueueITClipApp.swift
//  QueueITClip
//
//  TESTING — plain "Run" from Xcode has no invocation URL, so the clip shows
//  the waiting screen. To test with a real join code use one of:
//
//  A) Xcode scheme environment variable:
//     Edit Scheme → Run → Arguments → Environment Variables
//     _XCAppClipURL = https://appclip.apple.com/id?p=DF.QueueIT12.Clip&code=PARTY123
//     (swap PARTY123 for a live join code)
//
//  B) On-device Local Experience (Settings → Developer → Local Experiences):
//     URL Prefix : https://appclip.apple.com/id?p=DF.QueueIT12.Clip
//     Bundle ID  : DF.QueueIT12.Clip
//     Then scan your InviteView QR code with the Camera app.
//

import SwiftUI

@main
struct QueueITClipApp: App {
    // Same config as main app – update for your environment
    private let supabaseURLString = "https://wbbcuuvoxgmtlqukbuzv.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndiYmN1dXZveGdtdGxxdWtidXp2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAzMzc4MzAsImV4cCI6MjA3NTkxMzgzMH0.7MUe9aUozsiDfKYbd8GuKhks07advqvg_v21cfZdvjc"
    private let backendURL = URL(string: "https://sallowly-intercommunicable-zonia.ngrok-free.dev")!

    @StateObject private var authService: AuthService
    @StateObject private var sessionCoordinator: SessionCoordinator

    init() {
        guard let url = URL(string: supabaseURLString) else {
            fatalError("Invalid Supabase URL")
        }
        let service = AuthService(supabaseURL: url, supabaseAnonKey: supabaseAnonKey)
        _authService = StateObject(wrappedValue: service)
        let apiService = QueueAPIService(baseURL: backendURL, authService: service)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(apiService: apiService))
    }

    var body: some Scene {
        WindowGroup {
            AppClipRootView()
                .environmentObject(authService)
                .environmentObject(sessionCoordinator)
                .preferredColorScheme(.dark)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    if let code = parseJoinCode(from: url) {
                        sessionCoordinator.pendingJoinCode = code
                    }
                }
                .onOpenURL { url in
                    if let code = parseJoinCode(from: url) {
                        sessionCoordinator.pendingJoinCode = code
                    }
                }
        }
    }

    private func parseJoinCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
            return code
        }
        let path = url.pathComponents
        if let idx = path.firstIndex(of: "join"), idx + 1 < path.count {
            return path[idx + 1]
        }
        if url.scheme == "queueit", url.host == "join" {
            return components?.queryItems?.first(where: { $0.name == "code" })?.value
        }
        return nil
    }
}
