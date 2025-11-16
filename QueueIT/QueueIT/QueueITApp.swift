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
    
    // Configuration - update these for your environment
    private let supabaseURL = "https://your-project.supabase.co"
    private let supabaseAnonKey = "your-anon-key"
    private let backendURL = URL(string: "http://localhost:8000")!
    
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
        // Initialize auth service
        let auth = AuthService(supabaseURL: supabaseURL, supabaseAnonKey: supabaseAnonKey)
        _authService = StateObject(wrappedValue: auth)
        
        // Initialize API service with auth
        let apiService = QueueAPIService(baseURL: backendURL, authService: auth)
        
        // Initialize session coordinator
        let coordinator = SessionCoordinator(apiService: apiService)
        _sessionCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(sessionCoordinator)
                .preferredColorScheme(.dark) // Force dark mode for party aesthetic
        }
        .modelContainer(sharedModelContainer)
    }
}
