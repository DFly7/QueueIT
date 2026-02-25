//
//  NowPlayingCard.swift
//  QueueIT
//
//  Hero Now Playing display with bold typography
//

import SwiftUI

struct NowPlayingCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @State private var voteAnimation: Bool = false
    @State private var imageLoaded = false
    
    var body: some View {
        VStack(spacing: AppTheme.spacingL) {
            // Album art - prominent
            Group {
                if let imageUrl = queuedSong.song.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            placeholderImage
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 260, height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusL))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusL)
                                        .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: AppTheme.accent.opacity(0.2), radius: 24, y: 12)
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
            
            // Track info
            VStack(spacing: AppTheme.spacingS) {
                Text(queuedSong.song.name)
                    .font(AppTheme.title())
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(queuedSong.song.album)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal)
            
            // Vote section
            HStack(spacing: AppTheme.spacingXL) {
                Button(action: { vote(value: -1) }) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: AppTheme.spacingXS) {
                    Text("\(queuedSong.votes)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accent)
                        .scaleEffect(voteAnimation ? 1.15 : 1.0)
                        .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                    
                    Text("votes")
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(minWidth: 60)
                
                Button(action: { vote(value: 1) }) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, AppTheme.spacingS)
            
            Text("Added by \(queuedSong.addedBy.username ?? "Unknown")")
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadiusL)
    }
    
    private var placeholderImage: some View {
        ZStack {
            AppTheme.surfaceElevated
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusL))
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
