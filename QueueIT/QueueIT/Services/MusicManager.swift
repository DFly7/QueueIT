import Foundation
import MusicKit
import Combine

@Observable
class MusicManager {
    var isAuthorized = false
    var canPlayMusic = false
    var isPlaying: Bool = false
    
    static let shared = MusicManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var onSongFinished: (() -> Void)?
    private var pollTask: Task<Void, Never>?
    private var playStartedAt: Date?
    private var currentSongDuration: TimeInterval?
    private var hasTriggeredFinished = false
    private var lastPlaybackTime: TimeInterval = 0
    private var playbackStallCount: Int = 0
    private var wasNearEnd: Bool = false
    
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
        self.currentSongDuration = song.duration
        self.hasTriggeredFinished = false
        self.isPlaying = true
        self.lastPlaybackTime = 0
        self.playbackStallCount = 0
        self.wasNearEnd = false
        
        print("🎵 MusicManager: Starting playback of '\(song.title)' (duration: \(song.duration ?? 0)s)")
        
        do {
            player.queue = [song]
            try await player.play()
            
            // Monitor via both Combine (fast path) and polling (reliable fallback)
            // Apple Music's objectWillChange can be unreliable when song ends
            startMonitoringPlayback()
            startPollingForSongEnd()
        } catch {
            print("❌ MusicManager: Failed to play song: \(error.localizedDescription)")
            self.isPlaying = false
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
        var pollCount = 0
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second (faster polling)
                guard !Task.isCancelled else { break }
                pollCount += 1
                // Log every 10 seconds to show polling is active
                if pollCount % 10 == 0 {
                    let player = ApplicationMusicPlayer.shared
                    print("🔍 MusicManager: Poll #\(pollCount) - status: \(player.state.playbackStatus), time: \(player.playbackTime)/\(currentSongDuration ?? 0), queueEntry: \(player.queue.currentEntry != nil)")
                }
                await checkIfSongFinished()
                guard onSongFinished != nil else { break } // Already fired, stop polling
            }
        }
    }
    
    @MainActor
    private func checkIfSongFinished() async {
        guard onSongFinished != nil, !hasTriggeredFinished else { return }
        
        // Grace period: ignore for first 3 seconds after play() - avoids false positives during
        // song transitions when playbackTime/state can be stale from the previous track
        if let started = playStartedAt, Date().timeIntervalSince(started) < 3 {
            return
        }
        
        let player = ApplicationMusicPlayer.shared
        let playbackStatus = player.state.playbackStatus
        let currentEntry = player.queue.currentEntry
        let playbackTime = player.playbackTime
        
        // Multiple conditions that indicate song finished:
        // 1. Queue is empty and not playing
        let queueEmpty = currentEntry == nil
        let notPlaying = playbackStatus != .playing
        
        // 2. Playback time reached near the end of duration (within 1 second)
        var reachedEnd = false
        if let duration = currentSongDuration, duration > 0 {
            reachedEnd = playbackTime >= (duration - 1.0)
            // Track if we were recently near the end
            if playbackTime >= (duration - 5.0) {
                wasNearEnd = true
            }
        }
        
        // 3. Status is stopped or paused with empty queue
        let isStopped = playbackStatus == .stopped
        let isPausedWithEmptyQueue = playbackStatus == .paused && queueEmpty
        
        // 4. Detect stalled playback at end of song
        // If playback time hasn't changed for 2+ polls and we're near the end, song is done
        var stalledAtEnd = false
        if let duration = currentSongDuration, duration > 0 {
            let nearEnd = playbackTime >= (duration - 2.0)
            if abs(playbackTime - lastPlaybackTime) < 0.1 {
                playbackStallCount += 1
            } else {
                playbackStallCount = 0
            }
            // If stalled for 2+ seconds near end, consider it finished
            stalledAtEnd = nearEnd && playbackStallCount >= 2
        }
        
        // 5. Apple Music behavior: when song ends, it pauses and resets playbackTime to 0
        // Detect this by checking if we were near the end and now time is 0 with paused status
        let resetAfterEnd = wasNearEnd && playbackStatus == .paused && playbackTime < 1.0
        
        lastPlaybackTime = playbackTime
        
        let shouldTriggerFinished = (queueEmpty && notPlaying) || 
                                     (reachedEnd && notPlaying) || 
                                     isStopped ||
                                     isPausedWithEmptyQueue ||
                                     stalledAtEnd ||
                                     resetAfterEnd
        
        if shouldTriggerFinished {
            print("🏁 MusicManager: Song finished (status: \(playbackStatus), queueEmpty: \(queueEmpty), playbackTime: \(playbackTime), duration: \(currentSongDuration ?? 0), stalledAtEnd: \(stalledAtEnd), resetAfterEnd: \(resetAfterEnd))")
            triggerSongFinished()
        }
    }
    
    private func triggerSongFinished() {
        guard !hasTriggeredFinished else { return }
        hasTriggeredFinished = true
        isPlaying = false
        
        pollTask?.cancel()
        pollTask = nil
        playStartedAt = nil
        currentSongDuration = nil
        
        let callback = onSongFinished
        onSongFinished = nil
        callback?()
    }
    
    func pause() {
        ApplicationMusicPlayer.shared.pause()
    }
    
    func stop() {
        print("⏹️ MusicManager: Stopping playback")
        ApplicationMusicPlayer.shared.stop()
        pollTask?.cancel()
        pollTask = nil
        playStartedAt = nil
        currentSongDuration = nil
        hasTriggeredFinished = false
        isPlaying = false
        lastPlaybackTime = 0
        playbackStallCount = 0
        wasNearEnd = false
        cancellables.removeAll()
        onSongFinished = nil
    }
}
