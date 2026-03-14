//
//  UnifiedSearchView.swift
//  QueueIT
//
//  Unified search view based on Apple Music layout.
//  Works with any TrackSearchProvider (Apple Music or Spotify).
//

import SwiftUI

struct UnifiedSearchView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss

    @StateObject private var searchVM: UnifiedTrackSearchViewModel
    private let provider: any TrackSearchProvider

    @State private var addingTrackIds: Set<String> = []
    @State private var addedTrackIds: Set<String> = []
    @State private var errorMessage: String?

    init(provider: any TrackSearchProvider) {
        self.provider = provider
        _searchVM = StateObject(wrappedValue: UnifiedTrackSearchViewModel(provider: provider))
    }

    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground(showGrid: false)

                VStack(spacing: 0) {
                    searchBar

                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(AppTheme.coral)
                            Text(error)
                                .font(AppTheme.caption())
                                .foregroundColor(AppTheme.coral)
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if searchVM.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !searchVM.results.isEmpty {
                        resultsList
                    } else if !searchVM.query.isEmpty {
                        Text("No results found")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Spacer()
                    }
                }
            }
            .navigationTitle("Search \(provider.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))

            TextField("Search songs...", text: $searchVM.query)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchVM.query.isEmpty {
                Button(action: { searchVM.clearQuery() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding()
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchVM.results) { track in
                    TrackResultRow(
                        track: track,
                        isAdding: addingTrackIds.contains(track.id),
                        isAdded: addedTrackIds.contains(track.id)
                    ) {
                        Task { await addTrack(track) }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Add Track

    private func addTrack(_ track: Track) async {
        guard !addingTrackIds.contains(track.id) && !addedTrackIds.contains(track.id) else { return }

        withAnimation { errorMessage = nil }
        addingTrackIds.insert(track.id)

        let success = await sessionCoordinator.addSong(track: track)

        addingTrackIds.remove(track.id)

        if success {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                addedTrackIds.insert(track.id)
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            withAnimation {
                errorMessage = sessionCoordinator.error ?? "Failed to add song"
            }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation {
                    if errorMessage != nil { errorMessage = nil }
                }
            }
        }
    }
}

// MARK: - Track Result Row

struct TrackResultRow: View {
    let track: Track
    var isAdding: Bool = false
    var isAdded: Bool = false
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            ZStack {
                if let imageUrl = track.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.white.opacity(0.1)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                } else {
                    Color.white.opacity(0.1)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                }

                if isAdded {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.neonCyan.opacity(0.9))
                        .frame(width: 60, height: 60)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(AppTheme.body())
                    .foregroundColor(isAdded ? AppTheme.neonCyan : .white)
                    .lineLimit(1)

                Text(track.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                if isAdded {
                    Text("Added to queue!")
                        .font(AppTheme.monoSmall())
                        .foregroundColor(AppTheme.neonCyan)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text(track.album)
                        .font(AppTheme.caption())
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Add / loading / added state
            Group {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.neonCyan)
                        .transition(.scale.combined(with: .opacity))
                } else if isAdding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        .scaleEffect(0.9)
                } else {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .frame(width: 32, height: 32)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAdding)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAdded)
        }
        .padding()
        .background(isAdded ? AppTheme.neonCyan.opacity(0.08) : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isAdded ? AppTheme.neonCyan.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isAdded)
    }
}

#if !APPCLIP
#Preview {
    UnifiedSearchView(
        provider: AppleMusicTrackSearchProvider()
    )
    .environmentObject(SessionCoordinator.mock())
}
#endif
