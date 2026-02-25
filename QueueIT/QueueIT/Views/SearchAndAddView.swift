//
//  SearchAndAddView.swift
//  QueueIT
//
//  Search with refined cards and success feedback
//

import SwiftUI

struct SearchAndAddView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchVM = TrackSearchViewModel()
    
    @State private var justAddedTrackId: String?
    @State private var showSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if searchVM.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                        Spacer()
                    } else if let error = searchVM.errorMessage {
                        Spacer()
                        VStack(spacing: AppTheme.spacingM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.error)
                            Text(error)
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textSecondary)
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
                
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Add Music")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(AppTheme.headline())
                }
            }
            .onAppear {
                searchVM.setup(service: sessionCoordinator.apiService)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack(spacing: AppTheme.spacingM) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.textSecondary)
            
            TextField("Search for songs...", text: $searchVM.query)
                .textFieldStyle(.plain)
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit { Task { await searchVM.search() } }
            
            if !searchVM.query.isEmpty {
                Button(action: {
                    searchVM.query = ""
                    searchVM.results = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadius)
        .padding(AppTheme.spacingM)
    }
    
    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 100, height: 100)
                Image(systemName: "music.note.list")
                    .font(.system(size: 44))
                    .foregroundColor(AppTheme.textMuted)
            }
            
            Text("Search for music")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            
            Text("Find songs to add to the queue")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textMuted)
            Spacer()
        }
    }
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacingS) {
                ForEach(searchVM.results) { track in
                    SearchResultCard(
                        track: track,
                        isAdded: justAddedTrackId == track.id,
                        onAdd: { addTrack(track) }
                    )
                }
            }
            .padding(AppTheme.spacingM)
        }
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: AppTheme.spacingM) {
                ZStack {
                    Circle()
                        .fill(AppTheme.success.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(AppTheme.success)
                }
                
                Text("Added to Queue!")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(AppTheme.spacingXL)
            .background(AppTheme.surface)
            .cornerRadius(AppTheme.cornerRadiusL)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Actions
    
    private func addTrack(_ track: Track) {
        justAddedTrackId = track.id
        
        Task {
            await sessionCoordinator.addSong(track: track)
            
            withAnimation(AppTheme.bouncyAnimation) {
                showSuccessAnimation = true
            }
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            withAnimation {
                showSuccessAnimation = false
            }
            
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
        HStack(spacing: AppTheme.spacingM) {
            if let imageUrl = track.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                } placeholder: {
                    AppTheme.surfaceElevated
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS))
            } else {
                ZStack {
                    AppTheme.surfaceElevated
                    Image(systemName: "music.note")
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusS))
            }
            
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text(track.name)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(track.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: AppTheme.spacingS) {
                    Text(track.album)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textMuted.opacity(0.6))
                    
                    Text(track.durationFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            
            Spacer()
            
            Button(action: onAdd) {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.success)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }
            }
            .disabled(isAdded)
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadius)
        .scaleEffect(isAdded ? 0.98 : 1.0)
        .animation(AppTheme.quickAnimation, value: isAdded)
    }
}

#Preview {
    SearchAndAddView()
        .environmentObject(SessionCoordinator.mock())
}
