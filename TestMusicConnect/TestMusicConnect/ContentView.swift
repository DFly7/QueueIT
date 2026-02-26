//
//  ContentView.swift
//  TestMusicConnect
//
//  Created by Darragh Flynn on 20/02/2026.
//

import SwiftUI
import SwiftData
import MusicKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var musicManager = MusicManager()
    @State private var currentSong: Song?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 20) {
                if !musicManager.isAuthorized {
                    Button("Connect to Apple Music") {
                        Task { await musicManager.requestAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                } else if !musicManager.canPlayMusic {
                    Text("An active Apple Music subscription is required.")
                } else {
                    Button("Play 'Blinding Lights'") {
                        Task {
                            if let song = await searchForSong(query: "Blinding Lights") {
                                self.currentSong = song
                                await play(song: song)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if let song = currentSong {
                        Text("Now Playing: \(song.title) by \(song.artistName)")
                            .font(.headline)
                    }
                }
                
                Divider()
                
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                        } label: {
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .padding()
    }
    
    // MARK: - Music Logic
    
    func searchForSong(query: String) async -> Song? {
        do {
            // Create a search request for songs
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 1 // Just grab the top result
            
            let response = try await request.response()
            return response.songs.first
        } catch {
            print("Search failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func play(song: Song) async {
        let player = ApplicationMusicPlayer.shared
        
        do {
            // Set the player's queue to the song we found
            player.queue = [song]
            
            // Start playback!
            try await player.play()
        } catch {
            print("Failed to play song: \(error.localizedDescription)")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

@Observable // Use @Observable for iOS 17+
class MusicManager {
    var isAuthorized = false
    var canPlayMusic = false
    
    func requestAccess() async {
        // 1. Ask for permission
        let status = await MusicAuthorization.request()
        
        if status == .authorized {
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            // 2. Check if they have an active Apple Music Subscription
            await checkSubscription()
        }
    }
    
    private func checkSubscription() async {
        do {
            let subscription = try await MusicSubscription.current
            DispatchQueue.main.async {
                self.canPlayMusic = subscription.canPlayCatalogContent
            }
        } catch {
            print("Failed to check subscription: \(error)")
        }
    }
}
