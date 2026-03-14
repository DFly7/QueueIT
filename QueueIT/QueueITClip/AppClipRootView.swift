//
//  AppClipRootView.swift
//  QueueITClip
//
//  Orchestrates the App Clip boot sequence:
//  1. Wait for Supabase session restore
//  2. Sign in anonymously if needed
//  3. Show name prompt on first launch
//  4. Join session from pending join code
//  5. Hand off to AppClipGuestQueueView
//

import SwiftUI

struct AppClipRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator

    @State private var showNamePrompt = false
    @State private var isInitializing = true
    @State private var initError: String?

    var body: some View {
        ZStack {
            NeonBackground(showGrid: false)

            if isInitializing {
                initializingView
            } else if let error = initError {
                errorView(message: error)
            } else if sessionCoordinator.isInSession {
                AppClipGuestQueueView()
            } else {
                waitingForLinkView
            }
        }
        .sheet(isPresented: $showNamePrompt) {
            GuestNamePromptView(isPresented: $showNamePrompt) { confirmedName in
                // Update backend profile with the new display name
                Task {
                    try? await authService.updateProfile(
                        username: confirmedName,
                        musicProvider: "none",
                        storefront: nil
                    )
                }
            }
        }
        .task { await initializeClip() }
        // Handle invocation URL arriving after init + auth are both complete (warm launch).
        // During cold launch, initializeClip() handles joining after auth — skip here.
        .onChange(of: sessionCoordinator.pendingJoinCode) { _, newCode in
            guard let code = newCode,
                  !sessionCoordinator.isInSession,
                  !isInitializing,
                  authService.isAuthenticated else { return }
            Task { await joinWithCode(code) }
        }
    }

    // MARK: - Sub-views

    private var initializingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                .scaleEffect(1.4)

            Text("Joining the party…")
                .font(AppTheme.headline())
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var waitingForLinkView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.primaryGradient)
            }

            VStack(spacing: 8) {
                Text("Scan a QR code")
                    .font(AppTheme.title())
                    .foregroundColor(.white)

                Text("Ask the host to show you the invite QR code or share the link.")
                    .font(AppTheme.body())
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.coral)

            Text("Something went wrong")
                .font(AppTheme.headline())
                .foregroundColor(.white)

            Text(message)
                .font(AppTheme.body())
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                initError = nil
                isInitializing = true
                Task { await initializeClip() }
            }
            .font(AppTheme.headline())
            .foregroundColor(AppTheme.neonCyan)
        }
    }

    // MARK: - Initialization Sequence

    private func initializeClip() async {
        // 1. Wait for the initial Supabase session check to complete
        //    (AuthService.checkSession() runs in init and clears isCheckingInitialSession when done)
        while authService.isCheckingInitialSession {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s poll
        }

        // 2. If a real (non-anonymous) account is cached from a previous test run,
        //    sign it out first so the App Clip always uses an anonymous identity.
        if authService.isAuthenticated, authService.currentUser?.isAnonymous == false {
            authService.signOut()
            // Give signOut a moment to clear state
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        // 3. Sign in anonymously if there is no active anonymous session
        if !authService.isAuthenticated {
            let displayName = AppClipGuestName.displayName
            do {
                try await authService.signInAnonymously(displayName: displayName)
            } catch {
                initError = "Could not create a guest session: \(error.localizedDescription)"
                isInitializing = false
                return
            }
        }

        // 4. Show name prompt on first-ever launch
        if !AppClipGuestName.hasSetName {
            showNamePrompt = true
        }

        // 5. Join the session from the invocation URL
        if let code = sessionCoordinator.pendingJoinCode {
            await joinWithCode(code)
        }

        isInitializing = false
    }

    private func joinWithCode(_ code: String) async {
        sessionCoordinator.pendingJoinCode = nil
        
        // Validate join code from QR/deep link before attempting to join
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        if let validationError = Validator.validateJoinCode(trimmedCode) {
            await MainActor.run {
                initError = validationError.localizedDescription
                HapticFeedback.error()
            }
            return
        }
        
        await sessionCoordinator.joinSession(joinCode: trimmedCode)
        
        // Check if join failed
        if sessionCoordinator.error != nil {
            await MainActor.run {
                initError = sessionCoordinator.error
                HapticFeedback.error()
            }
        }
    }
}

#Preview {
    AppClipRootView()
        .environmentObject(AuthService.mock)
        .environmentObject(SessionCoordinator.mock())
}
