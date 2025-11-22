//
//  RootView.swift
//  QueueIT
//
//  Root coordinator that switches between Welcome and Session views
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingAuth = false
    
    var body: some View {
        Group {
            if !authService.isAuthenticated {
                authPrompt
            } else if sessionCoordinator.isInSession {
                SessionView()
            } else {
                WelcomeView()
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
                .environmentObject(authService)
        }
    }
    
    private var authPrompt: some View {
        ZStack {
            AppTheme.darkGradient
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundStyle(AppTheme.primaryGradient)
                    
                    Text("QueueUp")
                        .font(AppTheme.largeTitle())
                        .foregroundColor(.white)
                    
                    Text("Sign in to get started")
                        .font(AppTheme.body())
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Button(action: {
                    showingAuth = true
                }) {
                    Text("Sign In")
                        .gradientButton(gradient: AppTheme.primaryGradient)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseAnonKey: "key"))
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService(supabaseURL: URL(string: "")!, supabaseAnonKey: "")
        )))
}


