//
//  AppClipGuestQueueView.swift
//  QueueITClip
//
//  The two-screen guest experience:
//    Screen 1 — Queue View (now playing + upcoming songs + Add button)
//    Screen 2 — Search overlay (full-screen sheet)
//
//  Deliberately minimal: no host controls, no auth UI, no settings.
//

import SwiftUI

struct AppClipGuestQueueView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @EnvironmentObject var authService: AuthService

    @State private var showingSearch = false
    @State private var showingInvite = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            NeonBackground(showGrid: false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.spacingLg) {
                    sessionHeader
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    if let nowPlaying = sessionCoordinator.nowPlayingWithOptimisticVotes {
                        NowPlayingCard(queuedSong: nowPlaying)
                    } else {
                        emptyNowPlayingView
                    }

                    queueSection
                }
                .padding(AppTheme.spacing)
                .padding(.bottom, 100)
            }

            // Floating search bar
            VStack {
                Spacer()
                Button(action: { showingSearch = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Search for a song...")
                            .font(AppTheme.body())
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.black.opacity(0.4))
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(AppTheme.neonCyan.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(appeared ? 1 : 0.95)
                .opacity(appeared ? 1 : 0)
                .padding(.horizontal, AppTheme.spacing)
                .padding(.bottom, 8)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showingSearch) {
            // Always use the Spotify backend proxy in the App Clip (no Apple Music auth)
            UnifiedSearchView(
                provider: SpotifyTrackSearchProvider(apiService: sessionCoordinator.apiService)
            )
            .environmentObject(sessionCoordinator)
        }
        .sheet(isPresented: $showingInvite) {
            if let joinCode = sessionCoordinator.currentSession?.session.joinCode {
                InviteView(joinCode: joinCode)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(spacing: 8) {
            if let session = sessionCoordinator.currentSession?.session {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.neonCyan)

                    Text("Party Queue")
                        .font(AppTheme.headline())
                        .foregroundColor(.white)

                    Spacer()

                    // Invite / share button
                    Button(action: { showingInvite = true }) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }

                    // Guest pill
                    Text("GUEST")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.neonCyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.neonCyan.opacity(0.15))
                        .cornerRadius(20)
                }

                Text("Hosted by \(session.host.username ?? "Unknown")")
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Now Playing Empty State

    private var emptyNowPlayingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.circle")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.25))

            Text("Nothing playing yet")
                .font(AppTheme.headline())
                .foregroundColor(.white.opacity(0.6))

            Text("Add a song to get the party started!")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .frostedCard()
    }

    // MARK: - Queue Section

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
                emptyQueueView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(sessionCoordinator.queue) { song in
                        QueueItemCard(queuedSong: song)
                            .environmentObject(sessionCoordinator)
                    }
                }
            }
        }
    }

    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))

            Text("Queue is empty")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.4))

            Text("Tap + to add a song")
                .font(AppTheme.caption())
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .frostedCard()
    }

}

#Preview {
    AppClipGuestQueueView()
        .environmentObject(SessionCoordinator.mock())
        .environmentObject(AuthService.mock)
}
