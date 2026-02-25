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
    
    @State private var hasVoted: Bool = false
    @State private var voteAnimation: Bool = false
    @State private var appeared = false
    
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
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 4) {
                    Text("\(queuedSong.votes)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .scaleEffect(voteAnimation ? 1.15 : 1.0)
                        .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                    
                    Text("votes")
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(minWidth: 60)
                
                Button(action: { vote(value: 1) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                    .frame(width: 64, height: 64)
                    .background(AppTheme.neonCyan.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            
            Text("Added by \(queuedSong.addedBy.username ?? "Unknown")")
                .font(AppTheme.caption())
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(AppTheme.spacingLg)
        .frostedCard()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
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
