import Foundation
import SwiftUI
import Supabase

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: QueueIT.User? // Points to YOUR custom struct
    @Published var isLoading = false
    @Published var errorMessage: String?

//    private let supabaseURL = URL(string: "YOUR_URL")!
//    private let supabaseKey = "YOUR_KEY"
    let client: SupabaseClient
    
    // Add this property so your API service can read the token
    var accessToken: String? {
        // currentSession is the synchronous, cached session in the SDK
        return client.auth.currentSession?.accessToken
    }

    // Update init to accept the URL and Key
    init(supabaseURL: URL, supabaseAnonKey: String) {
            // 1. Create a custom configuration
            let configuration = URLSessionConfiguration.default
            
            // 2. Set timeout intervals to be more forgiving
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60
            configuration.waitsForConnectivity = true
            
            // 3. Create custom options with this config
            let options = SupabaseClientOptions(
                auth: .init(),
                global: .init(
                    session: URLSession(configuration: configuration)
                )
            )
            
            // 4. Initialize with options
            self.client = SupabaseClient(
                supabaseURL: supabaseURL,
                supabaseKey: supabaseAnonKey,
                options: options
            )
            
            Task { await checkSession() }
        }

    // MARK: - Profile Fetching
    
    func loadProfile(userId: UUID) async throws {
        do {
            // Fetch from your 'users' table in the 'public' schema
            let profile: QueueIT.User = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.currentUser = profile
            self.isAuthenticated = true
        } catch {
            print("Profile load failed: \(error)")
            throw error
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        do {
            // 1. Get the Auth Session
            let session = try await client.auth.session
            
            // 2. Use the Auth ID to get the App Profile
            try await loadProfile(userId: session.user.id)
        } catch {
            self.isAuthenticated = false
        }
    }
    
    func signOut() {
        Task {
            try? await client.auth.signOut()
            withAnimation {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }
    }

    // MARK: - Actions

    func signIn(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Log in to Auth
            let session = try await client.auth.signIn(email: email, password: password)
            
            // 2. Log in successful, now fetch the Profile
            try await loadProfile(userId: session.user.id)
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func register(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Create Auth User
            let response = try await client.auth.signUp(email: email, password: password)
            
            if let session = response.session {
                // 2. If auto-confirm is on, session exists. Fetch profile.
                // Note: You MUST have the SQL Trigger set up (see below) for this to work immediately.
                try await loadProfile(userId: session.user.id)
            } else {
                self.errorMessage = "Please check your email to confirm your account."
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Magic Link
     func sendMagicLink(email: String) async {
         isLoading = true
         errorMessage = nil
         defer { isLoading = false }

         do {
             try await client.auth.signInWithOTP(
                 email: email,
                 redirectTo: URL(string: "com.queueit.app://magiclink")
             )
             self.errorMessage = "Check your email for the login link!"
         } catch {
             self.errorMessage = error.localizedDescription
         }
     }

     // MARK: - Social Login (Google)
     func signInWithGoogle() async {
         isLoading = true
         defer { isLoading = false }
         
         do {
             // This opens the browser. The result comes back via handleIncomingURL
             let _ = try await client.auth.signInWithOAuth(
                 provider: .google,
                 redirectTo: URL(string: "com.queueit.app://google")
             )
         } catch {
             self.errorMessage = error.localizedDescription
         }
     }

     // MARK: - Sign In With Apple (Native)
     func signInWithApple(idToken: String, nonce: String) async {
         isLoading = true
         defer { isLoading = false }
         
         do {
             let session = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
             
             // FIX: Fetch profile instead of assigning user directly
             try await loadProfile(userId: session.user.id)
             
             withAnimation { self.isAuthenticated = true }
         } catch {
             self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
         }
     }
     
     // MARK: - Deep Link Handler
     func handleIncomingURL(_ url: URL) async {
         do {
             let session = try await client.auth.session(from: url)
             
             // FIX: Fetch profile instead of assigning user directly
             try await loadProfile(userId: session.user.id)
             
             withAnimation { self.isAuthenticated = true }
         } catch {
             print("Deep link error: \(error)")
             self.errorMessage = "Failed to verify login link."
         }
     }
 }


// MARK: - Preview Mock
extension AuthService {
    static var mock: AuthService {
        let service = AuthService(supabaseURL: URL(string: "")!, supabaseAnonKey: "")
        
        // Manually set the state for the preview
        service.isAuthenticated = true
        service.currentUser = User(
            id: UUID(),
            email: "preview@queueit.com",
            username: "Preview Host",
            avatarUrl: "https://i.pravatar.cc/300"
        )
        
        return service
    }
}
