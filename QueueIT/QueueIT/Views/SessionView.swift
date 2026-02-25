//
//  SessionView.swift
//  QueueIT
//
//  Main session view with hero Now Playing and refined queue
//

import SwiftUI

struct SessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingSearch = false
    @State private var showingHostControls = false
    @State private var headerAppeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.spacingL) {
                        // Session code badge
                        sessionHeader
                        
                        // Now Playing - hero section
                        if let nowPlaying = sessionCoordinator.nowPlaying {
                            NowPlayingCard(queuedSong: nowPlaying)
                        } else {
                            emptyNowPlaying
                        }
                        
                        // Queue
                        queueSection
                    }
                    .padding(AppTheme.spacingM)
                    .padding(.bottom, 100) // Space for FAB
                }
                
                // Floating Add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingSearch = true }) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accent)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 16, y: 6)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, AppTheme.spacingL)
                        .padding(.bottom, AppTheme.spacingL)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: leaveSession) {
                        HStack(spacing: AppTheme.spacingXS) {
                            Image(systemName: "chevron.left")
                            Text("Leave")
                        }
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.accent)
                    }
                }
                
                if sessionCoordinator.isHost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingHostControls = true }) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(AppTheme.accentTertiary)
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchAndAddView()
                    .environmentObject(sessionCoordinator)
            }
            .sheet(isPresented: $showingHostControls) {
                HostControlsView()
                    .environmentObject(sessionCoordinator)
            }
        }
        .onAppear {
            withAnimation(AppTheme.smoothAnimation) { headerAppeared = true }
        }
    }
    
    // MARK: - Subviews
    
    private var sessionHeader: some View {
        VStack(spacing: AppTheme.spacingS) {
            if let session = sessionCoordinator.currentSession?.session {
                Text(session.joinCode)
                    .font(AppTheme.mono())
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, AppTheme.spacingL)
                    .padding(.vertical, AppTheme.spacingS)
                    .background(AppTheme.surface)
                    .cornerRadius(AppTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
                    )
                
                Text("Hosted by \(session.host.username ?? "Unknown")")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.top, AppTheme.spacingS)
        .opacity(headerAppeared ? 1 : 0)
    }
    
    private var emptyNowPlaying: some View {
        VStack(spacing: AppTheme.spacingM) {
            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.textMuted)
            }
            
            Text("No track playing")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            
            Text("Add some music to get started!")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadiusL)
    }
    
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Text("Up Next")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Text("\(sessionCoordinator.queue.count) songs")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            if sessionCoordinator.queue.isEmpty {
                emptyQueue
            } else {
                VStack(spacing: AppTheme.spacingS) {
                    ForEach(sessionCoordinator.queue) { queuedSong in
                        QueueItemCard(queuedSong: queuedSong)
                    }
                }
            }
        }
    }
    
    private var emptyQueue: some View {
        VStack(spacing: AppTheme.spacingM) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.textMuted)
            
            Text("Queue is empty")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingXL)
        .background(AppTheme.surface)
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
