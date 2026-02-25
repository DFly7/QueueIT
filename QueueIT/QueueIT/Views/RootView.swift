//
//  RootView.swift
//  QueueIT
//
//  Root coordinator with neon club aesthetic
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
    }
    
    private var authPrompt: some View {
        ZStack {
            AppTheme.ambientGradient
                .ignoresSafeArea()
            
            AppTheme.glowGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .symbolEffect(.pulse, options: .repeating, value: appeared)
                    
                    VStack(spacing: 8) {
                        Text("QueueUp")
                            .font(AppTheme.displayTitle())
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Sign in to queue the music")
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: { showingAuth = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                            Text("Sign In")
                        }
                        .gradientButton(gradient: AppTheme.primaryGradient)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
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
