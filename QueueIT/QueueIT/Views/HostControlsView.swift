//
//  HostControlsView.swift
//  QueueIT
//
//  Host controls — crown aesthetic
//

import SwiftUI

struct HostControlsView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var isLocked: Bool = false
    @State private var showSkipConfirmation: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.ambientGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        
                        VStack(spacing: 14) {
                            skipButton
                            lockToggle
                            sessionInfoCard
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPrimary)
                }
            }
        }
        .confirmationDialog(
            "Skip Current Track?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip", role: .destructive) {
                Task {
                    await sessionCoordinator.skipCurrentTrack()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately skip to the next song in the queue.")
        }
    }
    
    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.secondaryGradient)
            
            Text("Host Controls")
                .font(AppTheme.largeTitle())
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Manage your session")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 24)
    }
    
    private var skipButton: some View {
        Button(action: { showSkipConfirmation = true }) {
            HStack(spacing: 14) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.secondaryGradient)
                
                Text("Skip Current Track")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(18)
            .background(AppTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(sessionCoordinator.nowPlaying == nil)
        .opacity(sessionCoordinator.nowPlaying == nil ? 0.6 : 1)
    }
    
    private var lockToggle: some View {
        HStack(spacing: 14) {
            Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.primaryGradient)
            
            Text("Lock Queue")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isLocked)
                .labelsHidden()
                .tint(AppTheme.accentPrimary)
        }
        .padding(18)
        .background(AppTheme.surfaceCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(12)
        .onChange(of: isLocked) { _, newValue in
            Task {
                await sessionCoordinator.toggleLock(locked: newValue)
            }
        }
    }
    
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Session Code")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                if let joinCode = sessionCoordinator.currentSession?.session.joinCode {
                    Text(joinCode)
                        .font(AppTheme.monoCode())
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceElevated)
                        .cornerRadius(8)
                }
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            HStack {
                Text("Queue Size")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text("\(sessionCoordinator.queue.count) songs")
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(20)
        .background(AppTheme.surfaceCard.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    HostControlsView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService.mock
        )))
}
