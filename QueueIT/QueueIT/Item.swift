//
//  Item.swift
//  QueueIT
//
//  Created by Darragh Flynn on 12/10/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
