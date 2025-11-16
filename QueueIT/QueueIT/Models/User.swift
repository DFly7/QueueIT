//
//  User.swift
//  QueueIT
//
//  Models matching backend schema
//

import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
    }
}


