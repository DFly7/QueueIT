//
//  SimpleAuthView.swift
//  QueueIT
//
//  Simple authentication view (mock for development)
//

import SwiftUI

struct SimpleAuthView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.darkGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(AppTheme.primaryGradient)
                        
                        Text("Sign In")
                            .font(AppTheme.title())
                            .foregroundColor(.white)
                        
                        Text("Enter your email to continue")
                            .font(AppTheme.body())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Email input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(AppTheme.caption())
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(AppTheme.body())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                    }
                    .padding(.horizontal, 32)
                    
                    // Sign in button
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: AppTheme.buttonHeight)
                        } else {
                            Text("Continue")
                                .gradientButton(
                                    gradient: AppTheme.primaryGradient,
                                    isEnabled: isValidEmail
                                )
                        }
                    }
                    .disabled(!isValidEmail || isLoading)
                    .padding(.horizontal, 32)
                    
                    Text("Development mode: mock authentication")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 8)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
    
    private var isValidEmail: Bool {
        email.contains("@") && email.count > 3
    }
    
    private func signIn() {
        isLoading = true
        
        // Mock sign in for development
        // In production, integrate Supabase Auth SDK
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            authService.mockSignIn(email: email)
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    SimpleAuthView()
        .environmentObject(AuthService(supabaseURL: "https://example.supabase.co", supabaseAnonKey: "key"))
}


