//
//  AppleMusicSearchView.swift
//  QueueIT
//
//  Search Apple Music catalog and add songs to queue
//

import SwiftUI
import MusicKit

struct AppleMusicSearchView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [Song] = []
    @State private var isSearching: Bool = false
    @State private var addingSongIds: Set<MusicItemID> = []
    @State private var addedSongIds: Set<MusicItemID> = []
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground(showGrid: false)
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search songs...", text: $searchQuery)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchQuery) { _, newValue in
                                if !newValue.isEmpty {
                                    Task {
                                        await performSearch(query: newValue)
                                    }
                                }
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                    
                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(AppTheme.coral)
                            Text(error)
                                .font(AppTheme.caption())
                                .foregroundColor(AppTheme.coral)
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Results
                    if isSearching {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty && !searchQuery.isEmpty {
                        Text("No results found")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults, id: \.id) { song in
                                    AppleMusicResultRow(
                                        song: song,
                                        isAdding: addingSongIds.contains(song.id),
                                        isAdded: addedSongIds.contains(song.id)
                                    ) {
                                        Task {
                                            await addSong(song)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Search Apple Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        searchResults = await MusicManager.shared.searchCatalog(query: query)
        isSearching = false
    }
    
    private func addSong(_ song: Song) async {
        guard !addingSongIds.contains(song.id) && !addedSongIds.contains(song.id) else { return }
        
        // Clear any previous error
        withAnimation {
            errorMessage = nil
        }
        
        // Mark as adding
        addingSongIds.insert(song.id)
        
        let track = song.toTrack()
        let success = await sessionCoordinator.addSong(track: track)
        
        // Remove from adding state
        addingSongIds.remove(song.id)
        
        if success {
            // Mark as successfully added with animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                addedSongIds.insert(song.id)
            }
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            // Show error
            withAnimation {
                errorMessage = sessionCoordinator.error ?? "Failed to add song"
            }
            
            // Clear error after a few seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation {
                    if errorMessage != nil {
                        errorMessage = nil
                    }
                }
            }
        }
    }
}

struct AppleMusicResultRow: View {
    let song: Song
    var isAdding: Bool = false
    var isAdded: Bool = false
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            ZStack {
                if let artwork = song.artwork {
                    AsyncImage(url: artwork.url(width: 60, height: 60)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.white.opacity(0.1)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                } else {
                    Color.white.opacity(0.1)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                }
                
                // Success checkmark overlay
                if isAdded {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.neonCyan.opacity(0.9))
                        .frame(width: 60, height: 60)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(AppTheme.body())
                    .foregroundColor(isAdded ? AppTheme.neonCyan : .white)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                if isAdded {
                    Text("Added to queue!")
                        .font(AppTheme.monoSmall())
                        .foregroundColor(AppTheme.neonCyan)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let album = song.albumTitle {
                    Text(album)
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Add button / Loading / Added state
            Group {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.neonCyan)
                        .transition(.scale.combined(with: .opacity))
                } else if isAdding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        .scaleEffect(0.9)
                } else {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .frame(width: 32, height: 32)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAdding)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAdded)
        }
        .padding()
        .background(isAdded ? AppTheme.neonCyan.opacity(0.08) : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isAdded ? AppTheme.neonCyan.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isAdded)
    }
}

#Preview {
    AppleMusicSearchView()
        .environmentObject(SessionCoordinator.mock())
}
