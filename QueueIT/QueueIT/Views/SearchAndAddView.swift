//
//  SearchAndAddView.swift
//  QueueIT
//
//  Enhanced search with instant add feedback and animations
//

import SwiftUI

struct SearchAndAddView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchVM: TrackSearchViewModel
    
    @State private var justAddedTrackId: String?
    @State private var showSuccessAnimation = false
    
    init() {
        // Initialize with proper API service
        _searchVM = StateObject(wrappedValue: TrackSearchViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.darkGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    // Results list
                    if searchVM.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Spacer()
                    } else if let error = searchVM.errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red.opacity(0.7))
                            Text(error)
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else if searchVM.results.isEmpty {
                        emptyState
                    } else {
                        resultsList
                    }
                }
                
                // Success overlay
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Add Music")
                        .font(AppTheme.headline())
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search for songs...", text: $searchVM.query)
                .textFieldStyle(PlainTextFieldStyle())
                .font(AppTheme.body())
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit {
                    Task { await searchVM.search() }
                }
            
            if !searchVM.query.isEmpty {
                Button(action: {
                    searchVM.query = ""
                    searchVM.results = []
                }) {
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
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Search for music")
                .font(AppTheme.headline())
                .foregroundColor(.white.opacity(0.7))
            
            Text("Find songs to add to the queue")
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchVM.results) { track in
                    SearchResultCard(
                        track: track,
                        isAdded: justAddedTrackId == track.id,
                        onAdd: {
                            addTrack(track)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(AppTheme.success)
                
                Text("Added to Queue!")
                    .font(AppTheme.headline())
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Actions
    
    private func addTrack(_ track: Track) {
        justAddedTrackId = track.id
        
        Task {
            await sessionCoordinator.addSong(track: track)
            
            // Show success animation
            withAnimation(AppTheme.bouncyAnimation) {
                showSuccessAnimation = true
            }
            
            // Hide after delay
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            withAnimation {
                showSuccessAnimation = false
            }
            
            // Clear the "added" state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                justAddedTrackId = nil
            }
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let track: Track
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            if let imageUrl = track.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(AppTheme.body())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(track.album)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(track.durationFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            // Add button
            Button(action: onAdd) {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.success)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.primaryGradient)
                }
            }
            .disabled(isAdded)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .scaleEffect(isAdded ? 0.98 : 1.0)
        .animation(AppTheme.quickAnimation, value: isAdded)
    }
}

#Preview {
    SearchAndAddView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService(supabaseURL: URL(string: "")!, supabaseAnonKey: "")
        )))
}


