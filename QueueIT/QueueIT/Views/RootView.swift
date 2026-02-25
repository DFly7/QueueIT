//
//  RootView.swift
//  QueueIT
//
//  Root coordinator with bold auth prompt
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingAuth = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
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
            AppTheme.background
                .ignoresSafeArea()
            
            // Subtle grid pattern
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, to: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(AppTheme.textMuted.opacity(0.08), lineWidth: 0.5)
            }
            
            VStack(spacing: AppTheme.spacingXL) {
                Spacer()
                
                VStack(spacing: AppTheme.spacingM) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(AppTheme.accent)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                    Text("QueueUp")
                        .font(AppTheme.displayLarge())
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Sign in to get started")
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Button(action: { showingAuth = true }) {
                    HStack(spacing: AppTheme.spacingS) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Sign In")
                    }
                    .primaryButton()
                }
                .padding(.horizontal, AppTheme.spacingXL)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(AppTheme.smoothAnimation) {
                logoScale = 1
                logoOpacity = 1
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
