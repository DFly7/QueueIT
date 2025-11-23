import SwiftUI
import AuthenticationServices
import CryptoKit // Required for Apple Sign In helper

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var authMode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    
    // Apple Sign In Helper State
    @State var currentNonce: String?

    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Register"
        case magicLink = "Magic Link"
    }

    var body: some View {
        ZStack {
            AppTheme.darkGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.primaryGradient)
                        Text("QueueUp")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                    // Mode Picker
                    Picker("Mode", selection: $authMode) {
                        ForEach(AuthMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Input Fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        if authMode != .magicLink {
                            SecureField("Password", text: $password)
                                .textContentType(authMode == .register ? .newPassword : .password)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }
                        
                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)

                    // Primary Action Button
                    Button(action: handleAction) {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(buttonTitle)
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding(.horizontal)
                    .disabled(email.isEmpty || (authMode != .magicLink && password.isEmpty))

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                        Text("OR").font(.caption).foregroundColor(.gray)
                        Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    // Social Login Section
                    VStack(spacing: 16) {
                        // Google Button
                        Button(action: {
                            Task { await authService.signInWithGoogle() }
                        }) {
                            HStack {
                                Image(systemName: "globe") // Replace with Google Icon asset
                                Text("Continue with Google")
                            }
                            .bold()
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                        
                        // Apple Button (Native)
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
                        .frame(height: 50)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers
    
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
    
    // Apple Sign In Logic
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
    
    // Standard Helper to generate Nonce for Apple Sign In
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
