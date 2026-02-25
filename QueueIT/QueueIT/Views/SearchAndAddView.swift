//
//  SearchAndAddView.swift
//  QueueIT
//
//  Search with instant add feedback
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
                AppTheme.ambientGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if searchVM.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentPrimary))
                        Spacer()
                    } else if let error = searchVM.errorMessage {
                        Spacer()
                        errorState(error)
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
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPrimary)
                }
            }
            .onAppear {
                searchVM.setup(service: sessionCoordinator.apiService)
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.textMuted)
            
            TextField("Search for songs...", text: $searchVM.query)
                .textFieldStyle(.plain)
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textPrimary)
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
                        .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .padding(16)
        .background(AppTheme.surfaceCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.destructive.opacity(0.8))
            
            Text(message)
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.2))
            
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
            LazyVStack(spacing: 10) {
                ForEach(searchVM.results) { track in
                    SearchResultCard(
                        track: track,
                        isAdded: justAddedTrackId == track.id,
                        onAdd: { addTrack(track) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.success)
                
                Text("Added to Queue!")
                    .font(AppTheme.headline())
                    .foregroundColor(.white)
            }
            .padding(44)
            .background(AppTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.success.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: AppTheme.success.opacity(0.2), radius: 24)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
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
        HStack(spacing: 14) {
            if let imageUrl = track.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                } placeholder: {
                    Color.white.opacity(0.1)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(track.artists)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
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
                        .foregroundStyle(AppTheme.success)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.primaryGradient)
                }
            }
            .disabled(isAdded)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(AppTheme.surfaceCard.opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(12)
        .scaleEffect(isAdded ? 0.98 : 1)
        .animation(AppTheme.quickAnimation, value: isAdded)
    }
}

#Preview {
    SearchAndAddView()
        .environmentObject(SessionCoordinator.mock())
}
