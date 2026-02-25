//
//  AuthView.swift
//  QueueIT
//
//  Auth sheet — neon club aesthetic
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

    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Register"
        case magicLink = "Magic Link"
    }

    var body: some View {
        ZStack {
            AppTheme.ambientGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    header
                    modePicker
                    inputFields
                    primaryButton
                    divider
                    socialButtons
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.primaryGradient)
            
            Text("QueueUp")
                .font(AppTheme.largeTitle())
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.top, 40)
        .padding(.bottom, 24)
    }
    
    private var modePicker: some View {
        Picker("Mode", selection: $authMode) {
            ForEach(AuthMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }
    
    private var inputFields: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .font(AppTheme.body())
                .foregroundColor(.white)
                .padding(16)
                .background(AppTheme.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(12)

            if authMode != .magicLink {
                SecureField("Password", text: $password)
                    .textContentType(authMode == .register ? .newPassword : .password)
                    .font(AppTheme.body())
                    .foregroundColor(.white)
                    .padding(16)
                    .background(AppTheme.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .cornerRadius(12)
            }
            
            if let error = authService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.destructive)
                    Text(error)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.destructive)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var primaryButton: some View {
        Button(action: handleAction) {
            if authService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.buttonHeight)
            } else {
                Text(buttonTitle)
                    .gradientButton(
                        gradient: AppTheme.primaryGradient,
                        isEnabled: !email.isEmpty && (authMode == .magicLink || !password.isEmpty)
                    )
            }
        }
        .disabled(email.isEmpty || (authMode != .magicLink && password.isEmpty) || authService.isLoading)
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }
    
    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.15))
            Text("OR")
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)
            Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.15))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    private var socialButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task { await authService.signInWithGoogle() }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                        .font(AppTheme.headline())
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
            
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
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
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
