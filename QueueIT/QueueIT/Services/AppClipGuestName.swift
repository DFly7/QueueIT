//
//  AppClipGuestName.swift
//  QueueIT / QueueITClip
//
//  Manages the anonymous display name shown in the queue ("Added by Neon Giraffe").
//  Add this file to BOTH the main app and App Clip targets in Xcode.
//

import Foundation
import Combine
import SwiftUI

enum AppClipGuestName {
    static let storageKey = "com.queueit.clip.guestDisplayName"

    /// Returns the saved display name, or a freshly generated random fun name.
    static var displayName: String {
        get { UserDefaults.standard.string(forKey: storageKey) ?? randomFunName }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    /// True once the user has explicitly confirmed a name (tapped "Let's Go").
    static var hasSetName: Bool {
        UserDefaults.standard.string(forKey: storageKey) != nil
    }

    /// Clears the stored name (useful for testing or sign-out).
    static func clearName() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Generates a random two-word name from the curated pool.
    static var randomFunName: String {
        let adjectives = [
            "Neon", "Cosmic", "Electric", "Phantom", "Velvet",
            "Solar", "Pixel", "Lunar", "Stellar", "Prism",
            "Turbo", "Mystic", "Glow", "Hyper", "Ultra"
        ]
        let nouns = [
            "Giraffe", "Panda", "Fox", "Wolf", "Owl",
            "Dragon", "Phoenix", "Panther", "Raven", "Jaguar",
            "Sloth", "Koala", "Dolphin", "Penguin", "Badger"
        ]
        return "\(adjectives.randomElement()!) \(nouns.randomElement()!)"
    }
}
