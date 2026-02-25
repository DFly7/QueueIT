//
//  WelcomeView.swift
//  QueueIT
//
//  Welcome screen with staggered entry and bold action cards
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingCreateSession = false
    @State private var showingJoinSession = false
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            AppTheme.ambientGradient
                .ignoresSafeArea()
            
            AppTheme.glowGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(AppTheme.primaryGradient)
                    
                    VStack(spacing: 6) {
                        Text("QueueUp")
                            .font(AppTheme.displayTitle())
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Collaborative music sessions")
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 48)
                
                VStack(spacing: 14) {
                    welcomeButton(
                        icon: "plus.circle.fill",
                        title: "Create Session",
                        subtitle: "Start a new party",
                        gradient: AppTheme.primaryGradient
                    ) {
                        showingCreateSession = true
                    }
                    
                    welcomeButton(
                        icon: "person.2.fill",
                        title: "Join Session",
                        subtitle: "Enter a code to join",
                        gradient: AppTheme.secondaryGradient
                    ) {
                        showingJoinSession = true
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                
                Spacer()
                
                if let user = authService.currentUser {
                    VStack(spacing: 8) {
                        Text("Signed in as")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Text(user.username ?? "User")
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Button("Sign Out") {
                            authService.signOut()
                        }
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.accentPrimary)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
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
    
    private func welcomeButton(
        icon: String,
        title: String,
        subtitle: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(gradient)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.headline())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(AppTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .cornerRadius(AppTheme.cornerRadius)
        }
        .buttonStyle(WelcomeButtonStyle())
    }
}

struct WelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(AppTheme.quickAnimation, value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.mock)
        .environmentObject(SessionCoordinator.mock())
}
