import Foundation
import MusicKit
import Combine

@Observable
class MusicManager {
    var isAuthorized = false
    var canPlayMusic = false
    
    static let shared = MusicManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var onSongFinished: (() -> Void)?
    
    private init() {}
    
    func requestAccess() async {
        let status = await MusicAuthorization.request()
        
        if status == .authorized {
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
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
    
    func searchForSong(query: String) async -> Song? {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 1
            
            let response = try await request.response()
            return response.songs.first
        } catch {
            print("Search failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Search Apple Music catalog and return up to 10 results
    func searchCatalog(query: String, limit: Int = 10) async -> [Song] {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = limit
            
            let response = try await request.response()
            return Array(response.songs)
        } catch {
            print("Catalog search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Play a song directly by its Apple Music catalog ID
    func playByCatalogID(_ catalogID: String, onFinished: @escaping () -> Void) async {
        do {
            let musicID = MusicItemID(catalogID)
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicID)
            let response = try await request.response()
            
            if let song = response.items.first {
                await play(song: song, onFinished: onFinished)
            } else {
                print("No song found for catalog ID: \(catalogID)")
            }
        } catch {
            print("Failed to play song by catalog ID: \(error.localizedDescription)")
        }
    }
    
    func play(song: Song, onFinished: @escaping () -> Void) async {
        let player = ApplicationMusicPlayer.shared
        self.onSongFinished = onFinished
        
        do {
            player.queue = [song]
            try await player.play()
            
            // Monitor playback state
            startMonitoringPlayback()
        } catch {
            print("Failed to play song: \(error.localizedDescription)")
        }
    }
    
    private func startMonitoringPlayback() {
        // Cancel previous subscriptions
        cancellables.removeAll()
        
        let player = ApplicationMusicPlayer.shared
        
        // Monitor both state AND queue - song end can be signaled by either
        // (queue.currentEntry becomes nil when last song ends; state may not always fire)
        player.state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkIfSongFinished()
                }
            }
            .store(in: &cancellables)
        
        player.queue.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkIfSongFinished()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func checkIfSongFinished() async {
        let player = ApplicationMusicPlayer.shared
        
        // Song finished: queue emptied (currentEntry nil) and not actively playing
        // Accept .stopped or .paused (player can end in either state when queue completes)
        let queueEmpty = player.queue.currentEntry == nil
        let notPlaying = player.state.playbackStatus != .playing
        if queueEmpty && notPlaying && onSongFinished != nil {
            print("Song finished playing")
            onSongFinished?()
            onSongFinished = nil
        }
    }
    
    func pause() {
        ApplicationMusicPlayer.shared.pause()
    }
    
    func stop() {
        ApplicationMusicPlayer.shared.stop()
        cancellables.removeAll()
        onSongFinished = nil
    }
}
