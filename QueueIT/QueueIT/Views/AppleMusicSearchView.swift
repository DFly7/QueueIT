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
                                    AppleMusicResultRow(song: song) {
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
        let track = song.toTrack()
        await sessionCoordinator.addSong(track: track)
        dismiss()
    }
}

struct AppleMusicResultRow: View {
    let song: Song
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
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
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(AppTheme.body())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                if let album = song.albumTitle {
                    Text(album)
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Add button
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.accent)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    AppleMusicSearchView()
        .environmentObject(SessionCoordinator.mock())
}
