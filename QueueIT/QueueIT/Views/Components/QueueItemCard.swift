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
    
    var body: some View {
        HStack(spacing: 14) {
            // Album art
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
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(queuedSong.song.name)
                    .font(AppTheme.body())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
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
            
            // Vote controls
            HStack(spacing: 10) {
                Button(action: { vote(value: -1) }) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Text("\(queuedSong.votes)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 28)
                    .scaleEffect(voteAnimation ? 1.25 : 1.0)
                    .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                
                Button(action: { vote(value: 1) }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.neonCyan.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.spacing)
        .frostedCard()
    }
    
    private func vote(value: Int) {
        voteAnimation = true
        Task {
            await sessionCoordinator.vote(on: queuedSong, value: value)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                voteAnimation = false
            }
        }
    }
}
