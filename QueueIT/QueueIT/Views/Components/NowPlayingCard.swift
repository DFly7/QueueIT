//
//  NowPlayingCard.swift
//  QueueIT
//
//  Hero Now Playing display with vinyl-inspired layout
//

import SwiftUI

struct NowPlayingCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @State private var voteAnimation: Bool = false
    @State private var appeared = false
    @State private var skipAnimation: Bool = false
    
    private var userVote: Int {
        sessionCoordinator.getUserVote(for: queuedSong.id)
    }
    
    // Get optimistic vote count from coordinator
    private var displayedVotes: Int {
        sessionCoordinator.getDisplayedVoteCount(for: queuedSong.id)
    }

    private var skipRequestCount: Int {
        sessionCoordinator.currentSession?.skipRequestCount ?? 0
    }

    private var participantCount: Int {
        max(sessionCoordinator.currentSession?.participantCount ?? 1, 1)
    }

    private var userRequestedSkip: Bool {
        sessionCoordinator.currentSession?.userRequestedSkip ?? false
    }

    private var skipFraction: Double {
        Double(skipRequestCount) / Double(participantCount)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Album art with vinyl ring effect
            ZStack {
                if appeared {
                    VinylRing(size: 320, opacity: 0.12)
                    VinylRing(size: 300, opacity: 0.08)
                }
                
                if let imageUrl = queuedSong.song.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 260, height: 260)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 260, height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg)
                                        .stroke(AppTheme.neonCyan.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: AppTheme.neonCyan.opacity(0.2), radius: 24, y: 8)
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            
            // Track info
            VStack(spacing: 8) {
                Text(queuedSong.song.name)
                    .font(AppTheme.title())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.headline())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(queuedSong.song.album)
                    .font(AppTheme.body())
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.spacing)
            
            // Vote section
            HStack(spacing: 32) {
                Button(action: { vote(value: -1) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 28))
                            .foregroundColor(userVote == -1 ? AppTheme.coral : .white.opacity(0.7))
                    }
                    .frame(width: 64, height: 64)
                    .background(userVote == -1 ? AppTheme.coral.opacity(0.2) : Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(userVote == -1 ? AppTheme.coral.opacity(0.5) : Color.white.opacity(0.06), lineWidth: userVote == -1 ? 2 : 1)
                    )
                    .scaleEffect(userVote == -1 ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .animation(AppTheme.bouncyAnimation, value: userVote)
                
                VStack(spacing: 4) {
                    Text("\(displayedVotes)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(voteCountGradient)
                        .scaleEffect(voteAnimation ? 1.15 : 1.0)
                        .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                        .contentTransition(.numericText(value: Double(displayedVotes)))
                    
                    Text(userVote != 0 ? "your vote counted!" : "votes")
                        .font(AppTheme.caption())
                        .foregroundColor(userVote != 0 ? AppTheme.neonCyan : .white.opacity(0.5))
                        .animation(.easeInOut, value: userVote)
                }
                .frame(minWidth: 60)
                
                Button(action: { vote(value: 1) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(userVote == 1 ? AnyShapeStyle(AppTheme.neonCyan) : AnyShapeStyle(AppTheme.primaryGradient))
                    }
                    .frame(width: 64, height: 64)
                    .background(AppTheme.neonCyan.opacity(userVote == 1 ? 0.3 : 0.15))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.neonCyan.opacity(userVote == 1 ? 0.8 : 0.3), lineWidth: userVote == 1 ? 2 : 1)
                    )
                    .scaleEffect(userVote == 1 ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .animation(AppTheme.bouncyAnimation, value: userVote)
            }
            .padding(.top, 8)
            
            // Crowdsourced skip section
            skipSection

            // Added by section with guest badge
            HStack(spacing: 6) {
                Image(systemName: queuedSong.addedBy.isAnonymous ? "person.fill.questionmark" : "person.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                
                Text("Added by")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                
                Text(queuedSong.addedBy.username ?? "Unknown")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                if queuedSong.addedBy.isAnonymous {
                    Text("GUEST")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.neonCyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.neonCyan.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
        .padding(AppTheme.spacingLg)
        .frostedCard()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    @ViewBuilder
    private var skipSection: some View {
        VStack(spacing: 8) {
            // Skip request button
            Button(action: requestSkip) {
                HStack(spacing: 8) {
                    Image(systemName: userRequestedSkip ? "checkmark.circle.fill" : "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(userRequestedSkip ? "Skip Requested" : "Request to Skip")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(userRequestedSkip ? AppTheme.neonCyan : .white.opacity(0.75))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    userRequestedSkip
                        ? AppTheme.neonCyan.opacity(0.15)
                        : Color.white.opacity(0.08)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            userRequestedSkip
                                ? AppTheme.neonCyan.opacity(0.6)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .clipShape(Capsule())
                .scaleEffect(skipAnimation ? 0.95 : 1.0)
            }
            .buttonStyle(.plain)
            .animation(AppTheme.bouncyAnimation, value: userRequestedSkip)
            .disabled(userRequestedSkip)

            // Skip progress bar + count label
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: skipFraction > 0.5
                                        ? [AppTheme.coral, AppTheme.coral.opacity(0.7)]
                                        : [AppTheme.neonCyan.opacity(0.6), AppTheme.neonCyan.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(skipFraction, 1.0))
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: skipFraction)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(skipRequestCount)/\(participantCount) players have requested to skip")
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Text("Over 50% skips")
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.top, 4)
    }

    private func requestSkip() {
        withAnimation(AppTheme.bouncyAnimation) { skipAnimation = true }
        Task {
            await sessionCoordinator.requestSkip()
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation { skipAnimation = false }
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "music.note")
                .font(.system(size: 72))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg))
    }
    
    private var voteCountGradient: AnyShapeStyle {
        if userVote == 1 {
            return AnyShapeStyle(LinearGradient(colors: [AppTheme.neonCyan, AppTheme.neonCyan.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        } else if userVote == -1 {
            return AnyShapeStyle(LinearGradient(colors: [AppTheme.coral, AppTheme.coral.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(AppTheme.primaryGradient)
    }
    
    private func vote(value: Int) {
        withAnimation(AppTheme.bouncyAnimation) {
            voteAnimation = true
        }
        
        Task {
            await sessionCoordinator.vote(on: queuedSong, value: value)
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation {
                voteAnimation = false
            }
        }
    }
}
