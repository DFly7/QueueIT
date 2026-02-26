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
    @State private var appeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.spacingLg) {
                        sessionHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                        
                        if let nowPlaying = sessionCoordinator.nowPlaying {
                            NowPlayingCard(queuedSong: nowPlaying)
                        } else {
                            emptyNowPlaying
                        }
                        
                        queueSection
                    }
                    .padding(AppTheme.spacing)
                    .padding(.bottom, 100)
                }
                
                // Floating Add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingSearch = true }) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primaryGradient)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 16, y: 4)
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)
                        .padding(.trailing, AppTheme.spacing)
                        .padding(.bottom, AppTheme.spacing)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: leaveSession) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Leave")
                                .font(AppTheme.headline())
                        }
                        .foregroundColor(AppTheme.neonCyan)
                    }
                }
                
                if sessionCoordinator.isHost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingHostControls = true }) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.warning.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.warning)
                            }
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
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    private var sessionHeader: some View {
        VStack(spacing: 10) {
            if let session = sessionCoordinator.currentSession?.session {
                Text(session.joinCode)
                    .font(AppTheme.mono())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                            .stroke(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(AppTheme.cornerRadiusSm)
                
                Text("Hosted by \(session.host.username ?? "Unknown")")
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.top, 8)
    }
    
    private var emptyNowPlaying: some View {
        VStack(spacing: 20) {
            ZStack {
                VinylRing(size: 140, opacity: 0.15)
                Image(systemName: "music.note.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.25))
            }
            
            Text("No track playing")
                .font(AppTheme.headline())
                .foregroundColor(.white.opacity(0.6))
            
            Text("Add some music to get started!")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .frostedCard()
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
                    .foregroundColor(.white.opacity(0.5))
            }
            
            if sessionCoordinator.queue.isEmpty {
                emptyQueue
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessionCoordinator.queue) { queuedSong in
                        QueueItemCard(queuedSong: queuedSong)
                    }
                }
            }
        }
    }
    
    private var emptyQueue: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.25))
            
            Text("Queue is empty")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .frostedCard()
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
