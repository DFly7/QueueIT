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

    private var cancellables = Set<AnyCancellable>()
    private var currentSearchTask: Task<Void, Never>? = nil
    
    // 1. Add a property to hold the service
    var apiService: QueueAPIService?

    init() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.triggerDebouncedSearch(for: newValue)
            }
            .store(in: &cancellables)
    }
    
    // 2. Helper to inject the service from the View
    func setup(service: QueueAPIService) {
        self.apiService = service
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
        
        // Safety check: Do we have the service?
        guard let apiService = apiService else {
            errorMessage = "API Service not configured"
            return
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }

        do {
            // 4. Call the centralized API logic!
            // This handles the Base URL, Auth Token, and Decoding for you.
            let searchResponse = try await apiService.searchTracks(query: trimmed)
            self.results = searchResponse.tracks
            
        } catch {
            if !Task.isCancelled {
                self.errorMessage = error.localizedDescription
                self.results = []
            }
        }
    }
}


