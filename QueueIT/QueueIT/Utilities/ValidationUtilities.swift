//
//  ValidationUtilities.swift
//  QueueIT
//
//  Created by Cursor AI
//

import Foundation

enum ValidationError: LocalizedError {
    case usernameTooShort
    case usernameTooLong
    case usernameInvalidCharacters
    case usernameEmpty
    case joinCodeTooShort
    case joinCodeTooLong
    case joinCodeInvalidCharacters
    case joinCodeEmpty
    
    var errorDescription: String? {
        switch self {
        case .usernameTooShort:
            return "Username must be at least 3 characters"
        case .usernameTooLong:
            return "Username cannot exceed 30 characters"
        case .usernameInvalidCharacters:
            return "Username can only contain letters, numbers, dashes, and underscores"
        case .usernameEmpty:
            return "Username is required"
        case .joinCodeTooShort:
            return "Join code must be at least 4 characters"
        case .joinCodeTooLong:
            return "Join code cannot exceed 20 characters"
        case .joinCodeInvalidCharacters:
            return "Join code can only contain letters, numbers, and hyphens"
        case .joinCodeEmpty:
            return "Join code is required"
        }
    }
}

struct Validator {
    /// Validates a username according to backend rules
    /// - Min: 3 characters
    /// - Max: 30 characters
    /// - Allowed: letters, numbers, hyphens (-), underscores (_)
    /// - Parameter username: The username to validate
    /// - Returns: ValidationError if invalid, nil if valid
    static func validateUsername(_ username: String) -> ValidationError? {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            return .usernameEmpty
        }
        
        if trimmed.count < 3 {
            return .usernameTooShort
        }
        
        if trimmed.count > 30 {
            return .usernameTooLong
        }
        
        // Check for valid characters: alphanumeric + hyphen + underscore
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let usernameCharacterSet = CharacterSet(charactersIn: trimmed)
        
        if !allowedCharacterSet.isSuperset(of: usernameCharacterSet) {
            return .usernameInvalidCharacters
        }
        
        return nil
    }
    
    /// Validates a join code according to backend rules
    /// - Min: 4 characters
    /// - Max: 20 characters
    /// - Allowed: letters, numbers, hyphens (-)
    /// - Parameter joinCode: The join code to validate
    /// - Returns: ValidationError if invalid, nil if valid
    static func validateJoinCode(_ joinCode: String) -> ValidationError? {
        let trimmed = joinCode.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            return .joinCodeEmpty
        }
        
        if trimmed.count < 4 {
            return .joinCodeTooShort
        }
        
        if trimmed.count > 20 {
            return .joinCodeTooLong
        }
        
        // Check for valid characters: alphanumeric + hyphen
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let joinCodeCharacterSet = CharacterSet(charactersIn: trimmed)
        
        if !allowedCharacterSet.isSuperset(of: joinCodeCharacterSet) {
            return .joinCodeInvalidCharacters
        }
        
        return nil
    }
}
