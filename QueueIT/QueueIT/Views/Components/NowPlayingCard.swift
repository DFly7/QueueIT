//
//  NowPlayingCard.swift
//  QueueIT
//
//  Large, prominent Now Playing display with vote buttons
//

import SwiftUI

struct NowPlayingCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @State private var hasVoted: Bool = false
    @State private var voteAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Album art
            if let imageUrl = queuedSong.song.imageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 280, height: 280)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, y: 10)
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
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
            .padding(.horizontal)
            
            // Vote section
            HStack(spacing: 40) {
                // Downvote
                Button(action: { vote(value: -1) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 70, height: 70)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                }
                
                // Vote count
                VStack(spacing: 4) {
                    Text("\(queuedSong.votes)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .scaleEffect(voteAnimation ? 1.2 : 1.0)
                        .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                    
                    Text("votes")
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Upvote
                Button(action: { vote(value: 1) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                    .frame(width: 70, height: 70)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                }
            }
            .padding(.top, 8)
            
            // Added by
            Text("Added by \(queuedSong.addedBy.username ?? "Unknown")")
                .font(AppTheme.caption())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(AppTheme.cornerRadius)
    }
    
    private var placeholderImage: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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


