//
//  SearchAndAddView.swift
//  QueueIT
//
//  Search with Neon Lounge styling and success feedback
//

import SwiftUI

struct SearchAndAddView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchVM = TrackSearchViewModel()
    
    @State private var justAddedTrackId: String?
    @State private var showSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground(showGrid: false)
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if searchVM.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        Spacer()
                    } else if let error = searchVM.errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.coral)
                            Text(error)
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Spacer()
                    } else if searchVM.results.isEmpty {
                        emptyState
                    } else {
                        resultsList
                    }
                }
                
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Add Music")
                        .font(AppTheme.headline())
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.neonCyan)
                    .font(AppTheme.headline())
                }
            }
            .onAppear {
                searchVM.setup(service: sessionCoordinator.apiService)
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
            
            TextField("Search for songs...", text: $searchVM.query)
                .textFieldStyle(.plain)
                .font(AppTheme.body())
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit {
                    Task { await searchVM.search() }
                }
            
            if !searchVM.query.isEmpty {
                Button(action: {
                    searchVM.query = ""
                    searchVM.results = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(AppTheme.spacing)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(AppTheme.cornerRadiusSm)
        .padding(AppTheme.spacing)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                VinylRing(size: 120, opacity: 0.15)
                Image(systemName: "music.note.list")
                    .font(.system(size: 52))
                    .foregroundColor(.white.opacity(0.25))
            }
            
            Text("Search for music")
                .font(AppTheme.headline())
                .foregroundColor(.white.opacity(0.6))
            
            Text("Find songs to add to the queue")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.45))
            Spacer()
        }
    }
    
    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(searchVM.results) { track in
                    SearchResultCard(
                        track: track,
                        isAdded: justAddedTrackId == track.id,
                        onAdd: { addTrack(track) }
                    )
                }
            }
            .padding(AppTheme.spacing)
        }
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppTheme.success.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.success)
                }
                
                Text("Added to Queue!")
                    .font(AppTheme.headline())
                    .foregroundColor(.white)
            }
            .padding(48)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLg)
                            .stroke(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: AppTheme.neonCyan.opacity(0.2), radius: 24)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private func addTrack(_ track: Track) {
        justAddedTrackId = track.id
        
        Task {
            await sessionCoordinator.addSong(track: track)
            
            withAnimation(AppTheme.bouncyAnimation) {
                showSuccessAnimation = true
            }
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            withAnimation {
                showSuccessAnimation = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                justAddedTrackId = nil
            }
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let track: Track
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            if let imageUrl = track.imageUrl {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(AppTheme.body())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(track.album)
                        .font(AppTheme.monoSmall())
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(track.durationFormatted)
                        .font(AppTheme.monoSmall())
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            Button(action: onAdd) {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.success)
                } else {
                    ZStack {
                        Circle()
                            .fill(AppTheme.neonCyan.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                }
            }
            .disabled(isAdded)
            .buttonStyle(.plain)
        }
        .padding(AppTheme.spacing)
        .frostedCard()
        .scaleEffect(isAdded ? 0.98 : 1.0)
        .animation(AppTheme.quickAnimation, value: isAdded)
    }
}

#Preview {
    SearchAndAddView()
        .environmentObject(SessionCoordinator.mock())
}
