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
    private var pollTask: Task<Void, Never>?
    private var playStartedAt: Date?
    
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
        self.playStartedAt = Date()
        
        do {
            player.queue = [song]
            try await player.play()
            
            // Monitor via both Combine (fast path) and polling (reliable fallback)
            // Apple Music's objectWillChange can be unreliable when song ends
            startMonitoringPlayback()
            startPollingForSongEnd()
        } catch {
            print("Failed to play song: \(error.localizedDescription)")
        }
    }
    
    private func startMonitoringPlayback() {
        cancellables.removeAll()
        let player = ApplicationMusicPlayer.shared
        
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
    
    /// Polling fallback - Apple Music often doesn't fire objectWillChange when song ends
    private func startPollingForSongEnd() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                guard !Task.isCancelled else { break }
                await checkIfSongFinished()
                guard onSongFinished != nil else { break } // Already fired, stop polling
            }
        }
    }
    
    @MainActor
    private func checkIfSongFinished() async {
        guard onSongFinished != nil else { return }
        
        // Grace period: ignore for first 5 seconds after play() - avoids false positives during
        // song transitions when playbackTime/state can be stale from the previous track
        if let started = playStartedAt, Date().timeIntervalSince(started) < 5 {
            return
        }
        
        let player = ApplicationMusicPlayer.shared
        let queueEmpty = player.queue.currentEntry == nil
        let notPlaying = player.state.playbackStatus != .playing
        
        if queueEmpty && notPlaying {
            print("Song finished playing")
            pollTask?.cancel()
            pollTask = nil
            playStartedAt = nil
            onSongFinished?()
            onSongFinished = nil
        }
    }
    
    func pause() {
        ApplicationMusicPlayer.shared.pause()
    }
    
    func stop() {
        ApplicationMusicPlayer.shared.stop()
        pollTask?.cancel()
        pollTask = nil
        playStartedAt = nil
        cancellables.removeAll()
        onSongFinished = nil
    }
}
