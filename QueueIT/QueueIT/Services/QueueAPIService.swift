//
//  QueueAPIService.swift
//  QueueIT
//
//  API client for all backend endpoints (sessions, queue, songs, voting)
//

import Foundation

class QueueAPIService {
    private let baseURL: URL
    public let authService: AuthService
    
    init(baseURL: URL, authService: AuthService) {
        self.baseURL = baseURL
        self.authService = authService
    }
    
    // MARK: - Helper Methods
    
    @MainActor private func createRequest(
        path: String,
        method: String,
        body: Encodable? = nil
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add Bearer token if authenticated
        if let token = authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        
        guard 200..<300 ~= http.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: http.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        // Use a custom date decoder that handles fractional seconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple ISO8601 formatters to handle different fractional second precisions
            let formatters: [ISO8601DateFormatter] = [
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime]
                    return formatter
                }()
            ]
            
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Log decoding errors for debugging
            print("❌ Failed to decode \(T.self): \(error)")
            throw error
        }
    }
    
    // MARK: - Sessions API
    
    func createSession(joinCode: String) async throws -> CurrentSessionResponse {
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
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/api/v1/spotify/search"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth header if available (search might be protected)
        if let token = await authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        else{
            print( "!!!!! No token found")
        }
        
        return try await performRequest(request, responseType: SearchResults.self)
    }
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        }
    }
}


