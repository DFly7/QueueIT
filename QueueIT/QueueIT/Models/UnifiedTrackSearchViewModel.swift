//
//  UnifiedTrackSearchViewModel.swift
//  QueueIT
//
//  ViewModel for unified search — debounces only for backend providers (Spotify).
//  Apple Music uses MusicKit client-side, so onChange is sufficient.
//

import Foundation
import Combine

@MainActor
final class UnifiedTrackSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var results: [Track] = []

    private let provider: any TrackSearchProvider
    private var cancellables = Set<AnyCancellable>()
    private var currentSearchTask: Task<Void, Never>?

    init(provider: any TrackSearchProvider) {
        self.provider = provider
        setupSearch()
    }

    private func setupSearch() {
        let queryPublisher = $query
            .removeDuplicates()

        if provider.shouldDebounce {
            queryPublisher
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .sink { [weak self] newValue in
                    self?.triggerSearch(for: newValue)
                }
                .store(in: &cancellables)
        } else {
            queryPublisher
                .sink { [weak self] newValue in
                    self?.triggerSearch(for: newValue)
                }
                .store(in: &cancellables)
        }
    }

    private func triggerSearch(for text: String) {
        currentSearchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 2 else {
            results = []
            errorMessage = nil
            return
        }
        currentSearchTask = Task { [weak self] in
            guard let self else { return }
            await self.performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        guard !Task.isCancelled else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let searchResults = try await provider.search(query: query, limit: 10)
            if !Task.isCancelled {
                self.results = searchResults
            }
        } catch {
            if !Task.isCancelled {
                self.errorMessage = error.localizedDescription
                self.results = []
            }
        }
    }

    func clearQuery() {
        query = ""
        results = []
        errorMessage = nil
    }
}
