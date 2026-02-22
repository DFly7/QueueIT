//
//  SessionView.swift
//  QueueIT
//
//  Main session view with Now Playing and Queue
//

import SwiftUI

struct SessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingSearch = false
    @State private var showingHostControls = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.darkGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Session info header
                        sessionHeader
                        
                        // Now Playing section
                        if let nowPlaying = sessionCoordinator.nowPlaying {
                            NowPlayingCard(queuedSong: nowPlaying)
                        } else {
                            emptyNowPlaying
                        }
                        
                        // Queue section
                        queueSection
                    }
                    .padding()
                }
                
                // Floating Add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingSearch = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppTheme.primaryGradient)
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 60, height: 60)
                                )
                                .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: leaveSession) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Leave")
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                }
                
                if sessionCoordinator.isHost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingHostControls = true
                        }) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(AppTheme.warning)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                AppleMusicSearchView()
                    .environmentObject(sessionCoordinator)
            }
            .sheet(isPresented: $showingHostControls) {
                HostControlsView()
                    .environmentObject(sessionCoordinator)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var sessionHeader: some View {
        VStack(spacing: 8) {
            if let session = sessionCoordinator.currentSession?.session {
                Text(session.joinCode)
                    .font(AppTheme.title())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                
                Text("Hosted by \(session.host.username ?? "Unknown")")
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }
    
    private var emptyNowPlaying: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.circle")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No track playing")
                .font(AppTheme.headline())
                .foregroundColor(.white.opacity(0.7))
            
            Text("Add some music to get started!")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(Color.white.opacity(0.05))
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Up Next")
                    .font(AppTheme.headline())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(sessionCoordinator.queue.count) songs")
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
            }
            
            if sessionCoordinator.queue.isEmpty {
                emptyQueue
            } else {
                ForEach(sessionCoordinator.queue) { queuedSong in
                    QueueItemCard(queuedSong: queuedSong)
                }
            }
        }
    }
    
    private var emptyQueue: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Queue is empty")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.05))
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private func leaveSession() {
        Task {
            await sessionCoordinator.leaveSession()
        }
    }
}

#Preview {
    SessionView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService(supabaseURL: URL(string: "")!, supabaseAnonKey: "")
        )))
}


