//
//  HostControlsView.swift
//  QueueIT
//
//  Host-only controls for managing session
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
                AppTheme.darkGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.warning)
                        
                        Text("Host Controls")
                            .font(AppTheme.title())
                            .foregroundColor(.white)
                        
                        Text("Manage your session")
                            .font(AppTheme.body())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Controls
                    VStack(spacing: 16) {
                        // Skip current track
                        Button(action: {
                            showSkipConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                Text("Skip Current Track")
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(sessionCoordinator.nowPlaying == nil)
                        
                        // Lock queue toggle
                        Toggle(isOn: $isLocked) {
                            HStack {
                                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                    .font(.title2)
                                Text("Lock Queue")
                            }
                            .foregroundColor(.white)
                        }
                        .tint(AppTheme.accent)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: isLocked) { _, newValue in
                            Task {
                                await sessionCoordinator.toggleLock(locked: newValue)
                            }
                        }
                        
                        // Session info
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Session Code")
                                    .font(AppTheme.caption())
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                if let joinCode = sessionCoordinator.currentSession?.session.joinCode {
                                    Text(joinCode)
                                        .font(AppTheme.headline())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            HStack {
                                Text("Queue Size")
                                    .font(AppTheme.caption())
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(sessionCoordinator.queue.count) songs")
                                    .font(AppTheme.body())
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
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
            authService: AuthService.mock)
        ));
}


