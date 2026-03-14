//
//  QueueItemCard.swift
//  QueueIT
//
//  Compact queue item with refined vote controls
//

import SwiftUI

struct QueueItemCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var voteAnimation: Bool = false
    
    private var userVote: Int {
        sessionCoordinator.getUserVote(for: queuedSong.id)
    }
    
    private var isPending: Bool {
        queuedSong.isPending
    }
    
    // Get optimistic vote count from coordinator
    private var displayedVotes: Int {
        sessionCoordinator.getDisplayedVoteCount(for: queuedSong.id)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art (slightly smaller)
            ZStack {
                if let imageUrl = queuedSong.song.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Pending indicator overlay
                if isPending {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 52, height: 52)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        .scaleEffect(0.7)
                }
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(queuedSong.song.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isPending ? .white.opacity(0.6) : .white)
                        .lineLimit(1)
                    
                    if isPending {
                        Text("Adding...")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.neonCyan)
                    }
                }
                
                Text(queuedSong.song.artists)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(isPending ? 0.4 : 0.55))
                    .lineLimit(1)
                
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                    Text(queuedSong.song.durationFormatted)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                // Added by (on separate line)
                HStack(spacing: 3) {
                    Image(systemName: queuedSong.addedBy.isAnonymous ? "person.fill.questionmark" : "person.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text(queuedSong.addedBy.username ?? "Unknown")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                    
                    if queuedSong.addedBy.isAnonymous {
                        Text("GUEST")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.neonCyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(AppTheme.neonCyan.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Vote controls (disabled for pending songs, more compact)
            if !isPending {
                HStack(spacing: 8) {
                    Button(action: { vote(value: -1) }) {
                        Image(systemName: userVote == -1 ? "arrow.down.circle.fill" : "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(userVote == -1 ? AppTheme.coral : .white.opacity(0.55))
                            .frame(width: 32, height: 32)
                            .background(userVote == -1 ? AppTheme.coral.opacity(0.2) : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(displayedVotes)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(voteColor)
                        .frame(minWidth: 24)
                        .scaleEffect(voteAnimation ? 1.25 : 1.0)
                        .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                    
                    Button(action: { vote(value: 1) }) {
                        Image(systemName: userVote == 1 ? "arrow.up.circle.fill" : "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(userVote == 1 ? AnyShapeStyle(AppTheme.neonCyan) : AnyShapeStyle(AppTheme.primaryGradient.opacity(0.7)))
                            .frame(width: 32, height: 32)
                            .background(AppTheme.neonCyan.opacity(userVote == 1 ? 0.3 : 0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frostedCard()
        .opacity(isPending ? 0.8 : 1.0)
    }
    
    private var voteColor: Color {
        if userVote == 1 {
            return AppTheme.neonCyan
        } else if userVote == -1 {
            return AppTheme.coral
        }
        return .white
    }
    
    private func vote(value: Int) {
        withAnimation(reduceMotion ? .none : AppTheme.bouncyAnimation) {
            voteAnimation = true
        }
        
        Task {
            await sessionCoordinator.vote(on: queuedSong, value: value)
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3)) {
                voteAnimation = false
            }
        }
    }
}
