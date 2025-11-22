//
//  WelcomeView.swift
//  QueueIT
//
//  Welcome screen with Create/Join session entry points
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingCreateSession = false
    @State private var showingJoinSession = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AppTheme.darkGradient
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo/Title area
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundStyle(AppTheme.primaryGradient)
                    
                    Text("QueueUp")
                        .font(AppTheme.largeTitle())
                        .foregroundColor(.white)
                    
                    Text("Collaborative music sessions")
                        .font(AppTheme.body())
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
                
                // Main action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showingCreateSession = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Create Session")
                        }
                        .gradientButton(gradient: AppTheme.primaryGradient)
                    }
                    .scaleEffect(showingCreateSession ? 0.95 : 1.0)
                    
                    Button(action: {
                        showingJoinSession = true
                    }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.title2)
                            Text("Join Session")
                        }
                        .gradientButton(gradient: AppTheme.secondaryGradient)
                    }
                    .scaleEffect(showingJoinSession ? 0.95 : 1.0)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // User info (if authenticated)
                if let user = authService.currentUser {
                    VStack(spacing: 8) {
                        Text("Signed in as")
                            .font(AppTheme.caption())
                            .foregroundColor(.white.opacity(0.5))
                        Text(user.username ?? "User")
                            .font(AppTheme.body())
                            .foregroundColor(.white)
                        
                        Button("Sign Out") {
                            authService.signOut()
                        }
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.accent)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 32)
                }
                else {
                    Button("Sign Out") {
                        authService.signOut()
                    }
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.accent)
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showingCreateSession) {
            CreateSessionView()
                .environmentObject(sessionCoordinator)
        }
        .sheet(isPresented: $showingJoinSession) {
            JoinSessionView()
                .environmentObject(sessionCoordinator)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService(supabaseURL: "https://example.supabase.co", supabaseAnonKey: "key"))
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService(supabaseURL: "", supabaseAnonKey: "")
        )))
}


