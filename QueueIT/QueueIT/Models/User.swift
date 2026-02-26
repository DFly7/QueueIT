//
//  User.swift
//  QueueIT
//
//  Models matching backend schema
//

import Foundation

// This matches your 'users' table in Supabase Database (public schema)
struct User: Identifiable, Codable, Hashable {
    let id: UUID
    let email: String? // Optional, if you duplicate it from auth
    let username: String?
    let avatarUrl: String?
    
    // Map snake_case from SQL to camelCase in Swift
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
    }
    
    // Convenience initializer for optimistic UI
    init(id: UUID, username: String?, email: String? = nil, avatarUrl: String? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.avatarUrl = avatarUrl
    }
}


