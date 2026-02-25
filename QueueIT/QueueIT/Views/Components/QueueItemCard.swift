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
        HStack(spacing: AppTheme.spacingM) {
            // Album art
            Group {
                if let imageUrl = queuedSong.song.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable()
                    } placeholder: {
                        AppTheme.surfaceElevated
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS))
                } else {
                    ZStack {
                        AppTheme.surfaceElevated
                        Image(systemName: "music.note")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS))
                }
            }
            
            // Track info
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text(queuedSong.song.name)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: AppTheme.spacingS) {
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
            
            Spacer(minLength: AppTheme.spacingS)
            
            // Vote controls
            HStack(spacing: AppTheme.spacingS) {
                Button(action: { vote(value: -1) }) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Text("\(queuedSong.votes)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(minWidth: 28)
                    .scaleEffect(voteAnimation ? 1.2 : 1.0)
                    .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                
                Button(action: { vote(value: 1) }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadius)
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
