//
//  NowPlayingCard.swift
//  QueueIT
//
//  Hero Now Playing — vinyl-inspired, prominent display
//

import SwiftUI

struct NowPlayingCard: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    let queuedSong: QueuedSongResponse
    
    @State private var voteAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            albumArtWithGlow
            
            VStack(spacing: 10) {
                Text(queuedSong.song.name)
                    .font(AppTheme.title())
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(queuedSong.song.artists)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                
                if !queuedSong.song.album.isEmpty {
                    Text(queuedSong.song.album)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            
            voteSection
            
            Text("Added by \(queuedSong.addedBy.username ?? "Unknown")")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(24)
        .background(AppTheme.surfaceCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.accentPrimary.opacity(0.3), AppTheme.accentSecondary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(AppTheme.cornerRadiusLg)
    }
    
    private var albumArtWithGlow: some View {
        ZStack {
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
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: AppTheme.accentPrimary.opacity(0.25), radius: 24, y: 8)
            } else {
                placeholderImage
            }
        }
    }
    
    private var voteSection: some View {
        HStack(spacing: 32) {
            Button(action: { vote(value: -1) }) {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            
            VStack(spacing: 4) {
                Text("\(queuedSong.votes)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .scaleEffect(voteAnimation ? 1.15 : 1)
                    .animation(AppTheme.bouncyAnimation, value: voteAnimation)
                
                Text("votes")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(minWidth: 60)
            
            Button(action: { vote(value: 1) }) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 8)
    }
    
    private var placeholderImage: some View {
        ZStack {
            AppTheme.surfaceElevated
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(width: 260, height: 260)
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

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(AppTheme.quickAnimation, value: configuration.isPressed)
    }
}
