//
//  HostControlsView.swift
//  QueueIT
//
//  Host controls with refined layout
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
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.spacingL) {
                        // Header
                        VStack(spacing: AppTheme.spacingM) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accentTertiary.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.accentTertiary)
                            }
                            
                            Text("Host Controls")
                                .font(AppTheme.largeTitle())
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Manage your session")
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, AppTheme.spacingXL)
                        
                        // Controls
                        VStack(spacing: AppTheme.spacingM) {
                            Button(action: { showSkipConfirmation = true }) {
                                HStack {
                                    Image(systemName: "forward.fill")
                                        .font(.title3)
                                    Text("Skip Current Track")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(AppTheme.spacingM)
                                .background(AppTheme.surface)
                                .cornerRadius(AppTheme.cornerRadius)
                            }
                            .disabled(sessionCoordinator.nowPlaying == nil)
                            .opacity(sessionCoordinator.nowPlaying == nil ? 0.5 : 1)
                            
                            HStack {
                                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                    .font(.title3)
                                Text("Lock Queue")
                                Spacer()
                                Toggle("", isOn: $isLocked)
                                    .labelsHidden()
                                    .tint(AppTheme.accent)
                            }
                            .font(AppTheme.headline())
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(AppTheme.spacingM)
                            .background(AppTheme.surface)
                            .cornerRadius(AppTheme.cornerRadius)
                            .onChange(of: isLocked) { _, newValue in
                                Task {
                                    await sessionCoordinator.toggleLock(locked: newValue)
                                }
                            }
                            
                            // Session info
                            VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                                HStack {
                                    Text("Session Code")
                                        .font(AppTheme.caption())
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    if let joinCode = sessionCoordinator.currentSession?.session.joinCode {
                                        Text(joinCode)
                                            .font(AppTheme.mono())
                                            .foregroundColor(AppTheme.textPrimary)
                                            .padding(.horizontal, AppTheme.spacingM)
                                            .padding(.vertical, AppTheme.spacingS)
                                            .background(AppTheme.surfaceElevated)
                                            .cornerRadius(AppTheme.cornerRadiusS)
                                    }
                                }
                                
                                Divider()
                                    .background(AppTheme.textMuted.opacity(0.3))
                                
                                HStack {
                                    Text("Queue Size")
                                        .font(AppTheme.caption())
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    Text("\(sessionCoordinator.queue.count) songs")
                                        .font(AppTheme.body())
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                            .padding(AppTheme.spacingM)
                            .background(AppTheme.surface)
                            .cornerRadius(AppTheme.cornerRadius)
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                        
                        Spacer()
                            .frame(height: AppTheme.spacingXL)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(AppTheme.headline())
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
}

#Preview {
    HostControlsView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService.mock
        )))
}
