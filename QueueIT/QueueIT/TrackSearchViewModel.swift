//
//  TrackSearchViewModel.swift
//  QueueIT
//
//  Created by Assistant on 13/10/2025.
//

import Foundation
import Combine

@MainActor
final class TrackSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var results: [Track] = []

    // Adjust to your backend base URL
    private let baseURL = URL(string: "http://localhost:8000")!
    private var cancellables = Set<AnyCancellable>()
    private var currentSearchTask: Task<Void, Never>? = nil

    init() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.triggerDebouncedSearch(for: newValue)
            }
            .store(in: &cancellables)
    }

    private func triggerDebouncedSearch(for text: String) {
        currentSearchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 2 else {
            // Clear when empty/too short
            results = []
            errorMessage = nil
            return
        }
        currentSearchTask = Task { [weak self] in
            guard let self else { return }
            await self.search()
        }
    }

    func search() async {
        if Task.isCancelled { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/api/v1/spotify/search"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: "10")
        ]

        guard let url = urlComponents.url else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard 200..<300 ~= http.statusCode else {
                let serverText = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "QueueIT.API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: serverText])
            }

            let decoded = try JSONDecoder().decode(SearchResults.self, from: data)
            results = decoded.tracks
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
}


