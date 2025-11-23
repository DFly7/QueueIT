//
//  QueueAPIService.swift
//  QueueIT
//
//  API client for all backend endpoints (sessions, queue, songs, voting)
//

import Foundation

class QueueAPIService {
    private let baseURL: URL
    // 1. AuthService is an Actor, so we must be careful how we access it
    public let authService: AuthService
    
    init(baseURL: URL, authService: AuthService) {
        self.baseURL = baseURL
        self.authService = authService
    }
    
    // MARK: - Helper Methods
    
    // 2. Removed @MainActor, added 'async'.
    // This allows us to 'await' the token from AuthService without freezing the UI.
    private func createRequest(
        path: String,
        method: String,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil // <--- Add this parameter
    ) async throws -> URLRequest {
        
        // 1. Construct URL with Query Parameters
        let fullURL = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: true)!
        
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        // 2. Create Request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 3. AUTOMATIC AUTH INJECTION
        // This now handles Auth for EVERYTHING (Sessions, Songs, and Search)
        if let token = await authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ Warning: Making request to \(path) without a token")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 4. Handle 401 Unauthorized specifically
        if http.statusCode == 401 {
            // Optional: Trigger a sign out if the token is invalid
            await authService.signOut()
            throw APIError.unauthorized
        }
        
        guard 200..<300 ~= http.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: http.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        
        // Date decoding strategy... (kept your existing logic)
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }()
            ]
            for formatter in formatters {
                if let date = formatter.date(from: dateString) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Sessions API
    
    func createSession(joinCode: String) async throws -> CurrentSessionResponse {
        // 5. 'await' is now required here because createRequest is async
        let request = try await createRequest(
            path: "/api/v1/sessions/create",
            method: "POST",
            body: SessionCreateRequest(joinCode: joinCode)
        )
        return try await performRequest(request, responseType: CurrentSessionResponse.self)
    }
    
    func joinSession(joinCode: String) async throws -> CurrentSessionResponse {
        let request = try await createRequest(
            path: "/api/v1/sessions/join",
            method: "POST",
            body: SessionJoinRequest(joinCode: joinCode)
        )
        return try await performRequest(request, responseType: CurrentSessionResponse.self)
    }
    
    func getCurrentSession() async throws -> CurrentSessionResponse {
        let request = try await createRequest(
            path: "/api/v1/sessions/current",
            method: "GET"
        )
        return try await performRequest(request, responseType: CurrentSessionResponse.self)
    }
    
    func leaveSession() async throws {
        let request = try await createRequest(
            path: "/api/v1/sessions/leave",
            method: "POST"
        )
        let _: [String: Bool] = try await performRequest(request, responseType: [String: Bool].self)
    }
    
    func controlSession(
        isLocked: Bool? = nil,
        skipCurrentTrack: Bool? = nil,
        pausePlayback: Bool? = nil
    ) async throws {
        let request = try await createRequest(
            path: "/api/v1/sessions/control_session",
            method: "PATCH",
            body: SessionControlRequest(
                isLocked: isLocked,
                skipCurrentTrack: skipCurrentTrack,
                pausePlayback: pausePlayback
            )
        )
        let _: [String: Bool] = try await performRequest(request, responseType: [String: Bool].self)
    }
    
    // MARK: - Queue & Songs API
    
    func addSong(_ request: AddSongRequest) async throws -> QueuedSongResponse {
        let urlRequest = try await createRequest(
            path: "/api/v1/songs/add",
            method: "POST",
            body: request
        )
        return try await performRequest(urlRequest, responseType: QueuedSongResponse.self)
    }
    
    func vote(queuedSongId: UUID, voteValue: Int) async throws -> VoteResponse {
        let request = try await createRequest(
            path: "/api/v1/songs/\(queuedSongId.uuidString)/vote",
            method: "POST",
            body: VoteRequest(voteValue: voteValue)
        )
        return try await performRequest(request, responseType: VoteResponse.self)
    }
    
    // MARK: - Spotify Search
    
    func searchTracks(query: String, limit: Int = 10) async throws -> SearchResults {
        // Define the query parameters here
        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        // Let createRequest handle the URL construction and Auth Header
        let request = try await createRequest(
            path: "/api/v1/spotify/search",
            method: "GET",
            queryItems: queryItems
        )
        
        return try await performRequest(request, responseType: SearchResults.self)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .serverError(let statusCode, let message): return "Server error (\(statusCode)): \(message)"
        case .decodingError: return "Failed to decode response"
        case .unauthorized: return "Unauthorized. Please sign in again."
        }
    }
}
