//
//  HapticFeedback.swift
//  QueueIT
//
//  Created by Cursor AI
//

import UIKit

enum HapticFeedback {
    /// Trigger a success haptic (medium impact)
    static func success() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Trigger an error haptic (rigid impact for sharp, firm feedback)
    static func error() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
    
    /// Trigger a warning haptic (light impact)
    static func warning() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
