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
        HStack(spacing: 14) {
            // Album art
            ZStack {
                if let imageUrl = queuedSong.song.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Pending indicator overlay
                if isPending {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 56, height: 56)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        .scaleEffect(0.8)
                }
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(queuedSong.song.name)
                        .font(AppTheme.body())
                        .foregroundColor(isPending ? .white.opacity(0.6) : .white)
                        .lineLimit(1)
                    
                    if isPending {
                        Text("Adding...")
                            .font(AppTheme.monoSmall())
                            .foregroundColor(AppTheme.neonCyan)
                    }
                }
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(isPending ? 0.4 : 0.6))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(queuedSong.song.durationFormatted)
                        .font(AppTheme.monoSmall())
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(queuedSong.addedBy.username ?? "Unknown")
                        .font(AppTheme.monoSmall())
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer(minLength: 8)
            
            // Vote controls (disabled for pending songs)
            if !isPending {
                HStack(spacing: 10) {
                    Button(action: { vote(value: -1) }) {
                        Image(systemName: userVote == -1 ? "arrow.down.circle.fill" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(userVote == -1 ? AppTheme.coral : .white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(userVote == -1 ? AppTheme.coral.opacity(0.2) : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(displayedVotes)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(voteColor)
                        .frame(minWidth: 28)
                        .scaleEffect(voteAnimation ? 1.25 : 1.0)
                        .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                    
                    Button(action: { vote(value: 1) }) {
                        Image(systemName: userVote == 1 ? "arrow.up.circle.fill" : "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(userVote == 1 ? AnyShapeStyle(AppTheme.neonCyan) : AnyShapeStyle(AppTheme.primaryGradient))
                            .frame(width: 36, height: 36)
                            .background(AppTheme.neonCyan.opacity(userVote == 1 ? 0.3 : 0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppTheme.spacing)
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
