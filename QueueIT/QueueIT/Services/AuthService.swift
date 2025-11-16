//
//  AuthService.swift
//  QueueIT
//
//  Handles Supabase authentication and JWT token management
//

import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var accessToken: String?
    
    private let supabaseURL: String
    private let supabaseAnonKey: String
    
    init(supabaseURL: String, supabaseAnonKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        loadStoredToken()
    }
    
    // MARK: - Token Management
    
    private func loadStoredToken() {
        if let token = UserDefaults.standard.string(forKey: "supabase_access_token") {
            self.accessToken = token
            self.isAuthenticated = true
            // In production, validate token expiry here
        }
    }
    
    func storeToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "supabase_access_token")
        self.accessToken = token
        self.isAuthenticated = true
    }
    
    func clearToken() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        self.accessToken = nil
        self.isAuthenticated = false
        self.currentUser = nil
    }
    
    // MARK: - Authentication Methods
    
    /// Send magic link to email (placeholder - implement Supabase auth in production)
    func sendMagicLink(email: String) async throws {
        // TODO: Integrate Supabase Auth SDK for production
        // For now, this is a placeholder for the auth flow
        
        let url = URL(string: "\(supabaseURL)/auth/v1/magiclink")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AuthError.authenticationFailed
        }
    }
    
    /// Sign out
    func signOut() {
        clearToken()
    }
    
    /// Mock sign in for development (replace with real Supabase auth)
    func mockSignIn(email: String) {
        // For development: create a mock JWT token
        // In production, this would come from Supabase Auth
//        let mockToken = "mock_jwt_token_for_dev_\(UUID().uuidString)"
        let mockToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6IjU3OWEwODNiLWFjMTMtNDQ2OC1iMTRmLTM5Y2QyZDc1YjhiZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL3diYmN1dXZveGdtdGxxdWtidXp2LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiJlZDdhMzczYy01YzhkLTQ0MmItYTBmNy04ZTE0NzkzZDE1ODkiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzYzMzE1OTI4LCJpYXQiOjE3NjMzMTIzMjgsImVtYWlsIjoiZGFycmFnaDJAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbF92ZXJpZmllZCI6dHJ1ZX0sInJvbGUiOiJhdXRoZW50aWNhdGVkIiwiYWFsIjoiYWFsMSIsImFtciI6W3sibWV0aG9kIjoicGFzc3dvcmQiLCJ0aW1lc3RhbXAiOjE3NjMzMTIzMjh9XSwic2Vzc2lvbl9pZCI6ImM0YjYzMTZkLTUzNDgtNGQzZi1iMjhlLTAyZGI1MTliNTAzNSIsImlzX2Fub255bW91cyI6ZmFsc2V9.ameyyutJKCxqZIpuu6zPKS1g06J_CPkz_ksgvmbcGka-v-NLyTOwNX8mB8A_rsIcmobtbNi3Sw_nw_qoWzn5Eg"
        
        storeToken(mockToken)
        
        self.currentUser = User(
            id: UUID(),
            username: email.components(separatedBy: "@").first
        )
    }
}

enum AuthError: Error, LocalizedError {
    case authenticationFailed
    case invalidToken
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .invalidToken:
            return "Your session has expired. Please sign in again."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}


