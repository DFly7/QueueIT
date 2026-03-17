//
//  WelcomeView.swift
//  QueueIT
//
//  Welcome screen with bold Create/Join entry points
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingCreateSession = false
    @State private var showingJoinSession = false
    @State private var showingAccount = false
    @State private var appeared = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            NeonBackground()

            // Host-ended-session toast
            if let message = toastMessage {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppTheme.neonCyan)
                        Text(message)
                            .font(AppTheme.body())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .fill(Color.black.opacity(0.75))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.neonCyan.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, AppTheme.spacingXl)
                    .padding(.top, 16)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    // Hero section
                    VStack(spacing: 20) {
                        ZStack {
                            VinylRing(size: 120, opacity: 0.25)
                            VinylRing(size: 80, opacity: 0.15)
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        
                        VStack(spacing: 8) {
                            Text("QueueUp")
                                .font(AppTheme.displayTitle())
                                .foregroundColor(.white)
                            
                            Text("Collaborative music sessions")
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)
                    }
                    .padding(.bottom, 48)
                    
                    // Action cards - asymmetric layout
                    VStack(spacing: 16) {
                        Button(action: { showingCreateSession = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primaryGradient.opacity(0.3))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryGradient)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Create Session")
                                        .font(AppTheme.headline())
                                        .foregroundColor(.white)
                                    Text("Start a new party")
                                        .font(AppTheme.caption())
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(AppTheme.spacingLg)
                            .frostedCard()
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(appeared ? 1 : 0.95)
                        .opacity(appeared ? 1 : 0)
                        
                        Button(action: { showingJoinSession = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.secondaryGradient.opacity(0.3))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(AppTheme.secondaryGradient)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Join Session")
                                        .font(AppTheme.headline())
                                        .foregroundColor(.white)
                                    Text("Enter a code to join")
                                        .font(AppTheme.caption())
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(AppTheme.spacingLg)
                            .frostedCard()
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(appeared ? 1 : 0.95)
                        .opacity(appeared ? 1 : 0)
                    }
                    .padding(.horizontal, AppTheme.spacingXl)
                    .padding(.bottom, 40)
                    
                    // User footer
                    if let user = authService.currentUser {
                        VStack(spacing: 12) {
                            Text("Signed in as")
                                .font(AppTheme.caption())
                                .foregroundColor(.white.opacity(0.4))
                            Text(user.username ?? "User")
                                .font(AppTheme.headline())
                                .foregroundColor(.white.opacity(0.9))
                            Button("Account") {
                                showingAccount = true
                            }
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.neonCyan)
                            .padding(.top, 4)
                        }
                        .padding(.bottom, 32)
                    }
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
        .sheet(isPresented: $showingAccount) {
            AccountSheet()
                .environmentObject(authService)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            // Handle deep link / QR scan that arrived before this view appeared
            if sessionCoordinator.pendingJoinCode != nil {
                showingJoinSession = true
            }
        }
        .onChange(of: sessionCoordinator.pendingJoinCode) { _, code in
            if code != nil {
                showingJoinSession = true
            }
        }
        .onChange(of: sessionCoordinator.hostEndedSession) { _, ended in
            if ended {
                sessionCoordinator.hostEndedSession = false
                showToast("The host has ended this session.")
            }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.mock)
        .environmentObject(SessionCoordinator.mock())
}
