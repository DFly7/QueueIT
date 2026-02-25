//
//  SessionView.swift
//  QueueIT
//
//  Main session view — vinyl hero, queue list, floating add
//

import SwiftUI

struct SessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingSearch = false
    @State private var showingHostControls = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.ambientGradient
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        sessionHeader
                        
                        if let nowPlaying = sessionCoordinator.nowPlaying {
                            NowPlayingCard(queuedSong: nowPlaying)
                        } else {
                            emptyNowPlaying
                        }
                        
                        queueSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addButton
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
                .allowsHitTesting(true)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: leaveSession) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Leave")
                                .font(AppTheme.headline())
                        }
                        .foregroundColor(AppTheme.accentPrimary)
                    }
                }
                
                if sessionCoordinator.isHost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingHostControls = true }) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(AppTheme.secondaryGradient)
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
    }
    
    private var addButton: some View {
        Button(action: { showingSearch = true }) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 60, height: 60)
                    .shadow(color: AppTheme.accentPrimary.opacity(0.4), radius: 16, y: 6)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(AddButtonStyle())
    }
    
    private var sessionHeader: some View {
        VStack(spacing: 10) {
            if let session = sessionCoordinator.currentSession?.session {
                Text(session.joinCode)
                    .font(AppTheme.monoCode())
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(AppTheme.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                
                Text("Hosted by \(session.host.username ?? "Unknown")")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(.top, 8)
    }
    
    private var emptyNowPlaying: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 160, height: 160)
                
                Image(systemName: "music.note")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.25))
            }
            
            Text("No track playing")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            
            Text("Add music to get the party started")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(AppTheme.surfaceCard.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(AppTheme.cornerRadiusLg)
    }
    
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Up Next")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Text("\(sessionCoordinator.queue.count) songs")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
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
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            
            Text("Queue is empty")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(AppTheme.surfaceCard.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private func leaveSession() {
        Task {
            await sessionCoordinator.leaveSession()
        }
    }
}

struct AddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(AppTheme.quickAnimation, value: configuration.isPressed)
    }
}

#Preview {
    SessionView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService(supabaseURL: URL(string: "")!, supabaseAnonKey: "")
        )))
}
