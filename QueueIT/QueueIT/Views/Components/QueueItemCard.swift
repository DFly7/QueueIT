//
//  QueueItemCard.swift
//  QueueIT
//
//  Compact queue item with vote controls
//

import SwiftUI

struct QueueItemCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @State private var voteAnimation: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            albumArt
            
            VStack(alignment: .leading, spacing: 4) {
                Text(queuedSong.song.name)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(queuedSong.song.durationFormatted)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textMuted.opacity(0.6))
                    
                    Text(queuedSong.addedBy.username ?? "Unknown")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            
            Spacer(minLength: 8)
            
            voteControls
        }
        .padding(14)
        .background(AppTheme.surfaceCard.opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var albumArt: some View {
        Group {
            if let imageUrl = queuedSong.song.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                } placeholder: {
                    Color.white.opacity(0.1)
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
        }
    }
    
    private var voteControls: some View {
        HStack(spacing: 10) {
            Button(action: { vote(value: -1) }) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            
            Text("\(queuedSong.votes)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .frame(minWidth: 28)
                .scaleEffect(voteAnimation ? 1.2 : 1)
                .animation(AppTheme.bouncyAnimation, value: voteAnimation)
            
            Button(action: { vote(value: 1) }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
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
