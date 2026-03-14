//
//  ProfileSetupView.swift
//  QueueIT
//
//  Profile setup after authentication (username + music provider selection)
//

import SwiftUI
import MusicKit

struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var selectedProvider: MusicProvider? = nil
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSpotifyComingSoon = false
    @State private var applePermissionGranted = false
    @State private var validationError: ValidationError?
    
    enum MusicProvider: String, CaseIterable {
        case apple = "apple"
        case spotify = "spotify"
        case none = "none"
        
        var displayName: String {
            switch self {
            case .apple: return "Apple Music"
            case .spotify: return "Spotify"
            case .none: return "None (Guest Only)"
            }
        }
        
        var icon: String {
            switch self {
            case .apple: return "music.note"
            case .spotify: return "music.note.list"
            case .none: return "person"
            }
        }
    }
    
    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        username.count >= 3 &&
        selectedProvider != nil
    }
    
    var body: some View {
        ZStack {
            // Neon Lounge Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Welcome to QueueIT")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Let's set up your profile")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    // Username Input
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Username", systemImage: "person.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Enter username", text: $username)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(validationError != nil ? Color.red.opacity(0.5) : Color.cyan.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: username) { _, _ in
                                // Clear validation error when user starts typing
                                if validationError != nil {
                                    validationError = nil
                                }
                            }
                        
                        if let validationError = validationError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.8))
                                Text(validationError.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Music Provider Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Music Provider", systemImage: "music.note")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Choose your streaming service (you can host sessions if you connect one)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        VStack(spacing: 12) {
                            ForEach(MusicProvider.allCases, id: \.self) { provider in
                                ProviderButton(
                                    provider: provider,
                                    isSelected: selectedProvider == provider,
                                    action: {
                                        handleProviderSelection(provider)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .padding(.horizontal)
                    }
                    
                    // Continue Button
                    Button {
                        Task { await completeSetup() }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isProcessing ? "Saving..." : "Continue")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: isFormValid ? [.cyan, .purple] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isProcessing)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Spotify Coming Soon", isPresented: $showSpotifyComingSoon) {
            Button("OK") { }
        } message: {
            Text("Spotify integration is coming soon! For now, please use Apple Music or None.")
        }
    }
    
    private func handleProviderSelection(_ provider: MusicProvider) {
        if provider == .spotify {
            // Stub: Show coming soon alert
            showSpotifyComingSoon = true
            return
        }
        
        if provider == .apple {
            // Request Apple Music permission
            Task {
                await requestAppleMusicPermission()
            }
        } else {
            // None - just select it
            selectedProvider = provider
        }
    }
    
    private func requestAppleMusicPermission() async {
        let status = await MusicAuthorization.request()
        
        await MainActor.run {
            if status == .authorized {
                selectedProvider = .apple
                applePermissionGranted = true
                errorMessage = nil
            } else {
                errorMessage = "Apple Music access is required. Please enable it in Settings."
            }
        }
    }
    
    private func completeSetup() async {
        guard isFormValid, let provider = selectedProvider else { return }
        
        // Validate username before proceeding
        if let error = Validator.validateUsername(username) {
            validationError = error
            HapticFeedback.error()
            return
        }
        
        isProcessing = true
        errorMessage = nil
        validationError = nil
        
        do {
            // Detect storefront if Apple Music
            var storefront = "us" // default
            if provider == .apple, applePermissionGranted {
                storefront = MusicDataRequest.currentCountryCode.lowercased()
            }
            
            // Call backend to update profile
            guard let backendURL = URL(string: "https://sallowly-intercommunicable-zonia.ngrok-free.dev") else {
                throw NSError(domain: "ProfileSetup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])
            }
            
            guard let token = authService.accessToken else {
                throw NSError(domain: "ProfileSetup", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }
            
            var request = URLRequest(url: backendURL.appendingPathComponent("/api/v1/users/me"))
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "username": username.trimmingCharacters(in: .whitespaces),
                "music_provider": provider.rawValue,
                "storefront": storefront
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "ProfileSetup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 200 {
                // Success - reload user profile
                if let userId = authService.currentUser?.id {
                    try await authService.loadProfile(userId: userId)
                }
            } else {
                // Parse backend error response
                let errorText = parseBackendError(data: data, statusCode: httpResponse.statusCode)
                await MainActor.run {
                    HapticFeedback.error()
                }
                throw NSError(domain: "ProfileSetup", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                HapticFeedback.error()
            }
        }
        
        isProcessing = false
    }
    
    private func parseBackendError(data: Data, statusCode: Int) -> String {
        // Try to parse JSON error response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check for "error" field (from exception handlers)
            if let errorMsg = json["error"] as? String {
                return errorMsg
            }
            // Check for "detail" field (from HTTPException)
            if let detail = json["detail"] as? String {
                return detail
            }
        }
        
        // Fallback to raw text
        if let errorText = String(data: data, encoding: .utf8), !errorText.isEmpty {
            return errorText
        }
        
        // Generic error based on status code
        switch statusCode {
        case 400: return "Invalid username format"
        case 409: return "Username already taken"
        default: return "Failed to update profile"
        }
    }
}

// MARK: - Provider Button Component

struct ProviderButton: View {
    let provider: ProfileSetupView.MusicProvider
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: provider.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.7))
                
                Text(provider.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cyan)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSetupView()
        .environmentObject(AuthService.mock)
}
