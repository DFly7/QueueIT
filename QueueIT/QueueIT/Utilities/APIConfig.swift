//
//  APIConfig.swift
//  QueueIT
//
//  Reads Backend URL, Supabase URL, and Supabase anon key from Info.plist.
//  Values are provided by .xcconfig at build time (Config-Debug / Config-Release).
//

import Foundation

enum APIConfig {
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Info.plist not found")
        }
        return dict
    }()

    static let backendURL: URL = {
        guard let urlString = infoDictionary["BackendURL"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            fatalError("BackendURL is invalid or missing in Info.plist. Check that .xcconfig is assigned in Project → Info → Configurations.")
        }
        return url
    }()

    static let supabaseURL: String = {
        guard let url = infoDictionary["SupabaseURL"] as? String, !url.isEmpty else {
            fatalError("SupabaseURL is invalid or missing in Info.plist")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = infoDictionary["SupabaseAnonKey"] as? String, !key.isEmpty else {
            fatalError("SupabaseAnonKey is invalid or missing in Info.plist")
        }
        return key
    }()
}
