//
//  QueueItemCard.swift
//  QueueIT
//
//  Compact queue item with vote buttons and track info
//

import SwiftUI

struct QueueItemCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @State private var voteAnimation: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art thumbnail
            if let imageUrl = queuedSong.song.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                
                HStack(spacing: 8) {
                    Text(queuedSong.song.durationFormatted)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(queuedSong.addedBy.username ?? "Unknown")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            // Vote controls
            HStack(spacing: 12) {
                Button(action: { vote(value: -1) }) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Text("\(queuedSong.votes)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 30)
                    .scaleEffect(voteAnimation ? 1.3 : 1.0)
                    .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                
                Button(action: { vote(value: 1) }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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


