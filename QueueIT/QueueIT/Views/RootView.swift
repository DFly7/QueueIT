//
//  RootView.swift
//  QueueIT
//
//  Root coordinator with Neon Lounge auth prompt
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingAuth = false
    @State private var appeared = false
    
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
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && showingAuth {
                // Dismiss auth sheet on successful login
                showingAuth = false
            }
        }
    }
    
    private var authPrompt: some View {
        ZStack {
            NeonBackground(showGrid: false)
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    ZStack {
                        VinylRing(size: 140, opacity: 0.2)
                        VinylRing(size: 100, opacity: 0.15)
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(AppTheme.primaryGradient)
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
                    
                    VStack(spacing: 8) {
                        Text("QueueUp")
                            .font(AppTheme.displayTitle())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("Sign in to start the party")
                            .font(AppTheme.body())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 48)
                
                Button(action: { showingAuth = true }) {
                    Text("Sign In")
                        .neonButton(gradient: AppTheme.primaryGradient)
                }
                .padding(.horizontal, AppTheme.spacingXl)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService.mock)
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService.mock
        )))
}
