//
//  Song+Track.swift
//  QueueIT
//
//  Extension to convert Apple Music Song to our Track model
//

import Foundation
import MusicKit

extension Song {
    /// Convert Apple Music Song to Track model for backend storage
    func toTrack() -> Track {
        Track(
            id: self.id.rawValue,
            isrc: self.isrc,
            name: self.title,
            artists: self.artistName,
            album: self.albumTitle ?? "",
            durationMs: Int((self.duration ?? 0) * 1000),
            imageUrl: self.artwork?.url(width: 300, height: 300),
            source: .appleMusic
        )
    }
}
