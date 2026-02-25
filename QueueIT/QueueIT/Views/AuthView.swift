//
//  AuthView.swift
//  QueueIT
//
//  Auth flow with refined form and social login
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var authMode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var contentOpacity: Double = 0
    @State var currentNonce: String?

    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Register"
        case magicLink = "Magic Link"
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Header
                    VStack(spacing: AppTheme.spacingM) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.15))
                                .frame(width: 88, height: 88)
                            
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.accent)
                        }
                        
                        Text("QueueUp")
                            .font(AppTheme.display())
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, AppTheme.spacingXL)
                    .padding(.bottom, AppTheme.spacingM)
                    .opacity(contentOpacity)

                    // Mode Picker
                    Picker("Mode", selection: $authMode) {
                        ForEach(AuthMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppTheme.spacingM)
                    .opacity(contentOpacity)

                    // Input Fields
                    VStack(spacing: AppTheme.spacingM) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(AppTheme.spacingM)
                            .background(AppTheme.surface)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.textMuted.opacity(0.3), lineWidth: 1)
                            )

                        if authMode != .magicLink {
                            SecureField("Password", text: $password)
                                .textContentType(authMode == .register ? .newPassword : .password)
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(AppTheme.spacingM)
                                .background(AppTheme.surface)
                                .cornerRadius(AppTheme.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                        .stroke(AppTheme.textMuted.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        if let error = authService.errorMessage {
                            HStack(spacing: AppTheme.spacingS) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text(error)
                                    .font(AppTheme.caption())
                                    .foregroundColor(AppTheme.error)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .opacity(contentOpacity)

                    // Primary Action
                    Button(action: handleAction) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: AppTheme.buttonHeight)
                        } else {
                            Text(buttonTitle)
                                .primaryButton(isEnabled: !email.isEmpty && (authMode == .magicLink || !password.isEmpty))
                        }
                    }
                    .disabled(email.isEmpty || (authMode != .magicLink && password.isEmpty))
                    .padding(.horizontal, AppTheme.spacingM)
                    .opacity(contentOpacity)

                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppTheme.textMuted.opacity(0.3))
                        Text("OR")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppTheme.textMuted.opacity(0.3))
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingS)
                    .opacity(contentOpacity)

                    // Social Login
                    VStack(spacing: AppTheme.spacingM) {
                        Button(action: {
                            Task { await authService.signInWithGoogle() }
                        }) {
                            HStack(spacing: AppTheme.spacingS) {
                                Image(systemName: "globe")
                                Text("Continue with Google")
                            }
                            .font(AppTheme.headline())
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(AppTheme.spacingM)
                            .background(AppTheme.surface)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.textMuted.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        SignInWithAppleButton(
                            onRequest: { request in
                                let nonce = randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = sha256(nonce)
                            },
                            onCompletion: { result in
                                handleAppleCompletion(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: AppTheme.buttonHeight)
                        .cornerRadius(AppTheme.cornerRadius)
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .opacity(contentOpacity)
                    
                    Spacer()
                        .frame(height: AppTheme.spacingXL)
                }
            }
        }
        .onAppear {
            withAnimation(AppTheme.smoothAnimation) { contentOpacity = 1 }
        }
    }

    var buttonTitle: String {
        switch authMode {
        case .signIn: return "Log In"
        case .register: return "Create Account"
        case .magicLink: return "Send Magic Link"
        }
    }

    func handleAction() {
        Task {
            switch authMode {
            case .signIn:
                await authService.signIn(email: email, password: password)
            case .register:
                await authService.register(email: email, password: password)
            case .magicLink:
                await authService.sendMagicLink(email: email)
            }
        }
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
            guard let nonce = currentNonce else { return }
            guard let idTokenData = appleIDCredential.identityToken,
                  let idTokenString = String(data: idTokenData, encoding: .utf8) else { return }
            
            Task {
                await authService.signInWithApple(idToken: idTokenString, nonce: nonce)
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess { fatalError("Unable to generate nonce") }
        return Data(randomBytes).map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
