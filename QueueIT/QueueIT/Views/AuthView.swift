//
//  AuthView.swift
//  QueueIT
//
//  Auth screen with Neon Lounge styling
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var authMode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State var currentNonce: String?
    @State private var appeared = false

    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Register"
        case magicLink = "Magic Link"
    }

    var body: some View {
        ZStack {
            NeonBackground(showGrid: false)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.spacingLg) {
                    VStack(spacing: 8) {
                        ZStack {
                            VinylRing(size: 100, opacity: 0.2)
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)
                        
                        Text("QueueUp")
                            .font(AppTheme.title())
                            .foregroundColor(.white)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 24)

                    Picker("Mode", selection: $authMode) {
                        ForEach(AuthMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppTheme.spacingXl)

                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .font(AppTheme.body())
                            .foregroundColor(.white)
                            .padding(AppTheme.spacing)
                            .background(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .cornerRadius(AppTheme.cornerRadiusSm)

                        if authMode != .magicLink {
                            SecureField("Password", text: $password)
                                .textContentType(authMode == .register ? .newPassword : .password)
                                .font(AppTheme.body())
                                .foregroundColor(.white)
                                .padding(AppTheme.spacing)
                                .background(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .cornerRadius(AppTheme.cornerRadiusSm)
                        }
                        
                        if let error = authService.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppTheme.coral)
                                Text(error)
                                    .font(AppTheme.caption())
                                    .foregroundColor(AppTheme.coral)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingXl)

                    Button(action: handleAction) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: AppTheme.buttonHeight)
                        } else {
                            Text(buttonTitle)
                                .neonButton(
                                    gradient: AppTheme.primaryGradient,
                                    isEnabled: !email.isEmpty && (authMode == .magicLink || !password.isEmpty)
                                )
                        }
                    }
                    .disabled(email.isEmpty || (authMode != .magicLink && password.isEmpty))
                    .padding(.horizontal, AppTheme.spacingXl)

                    HStack(spacing: 16) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.15))
                        Text("OR")
                            .font(AppTheme.caption())
                            .foregroundColor(.white.opacity(0.4))
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.15))
                    }
                    .padding(.horizontal, AppTheme.spacingXl)
                    .padding(.vertical, 8)

                    VStack(spacing: 12) {
                        Button(action: {
                            Task { await authService.signInWithGoogle() }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                Text("Continue with Google")
                                    .font(AppTheme.headline())
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(AppTheme.cornerRadius)
                        }
                        .buttonStyle(.plain)
                        
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
                        .frame(height: 52)
                        .cornerRadius(AppTheme.cornerRadius)
                    }
                    .padding(.horizontal, AppTheme.spacingXl)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
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
