//
//  CreateSessionView.swift
//  QueueIT
//
//  Create a new session with custom join code
//

import SwiftUI

struct CreateSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.darkGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Icon and title
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.primaryGradient)
                        
                        Text("Create Your Session")
                            .font(AppTheme.title())
                            .foregroundColor(.white)
                        
                        Text("Choose a unique join code that your friends can use")
                            .font(AppTheme.body())
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Join code input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join Code")
                            .font(AppTheme.caption())
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Enter code (4-20 characters)", text: $joinCode)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(AppTheme.headline())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    
                    // Error message
                    if let error = sessionCoordinator.error {
                        Text(error)
                            .font(AppTheme.caption())
                            .foregroundColor(.red)
                            .padding(.horizontal, 32)
                    }
                    
                    // Create button
                    Button(action: createSession) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: AppTheme.buttonHeight)
                        } else {
                            Text("Create Session")
                                .gradientButton(
                                    gradient: AppTheme.primaryGradient,
                                    isEnabled: isValidJoinCode
                                )
                        }
                    }
                    .disabled(!isValidJoinCode || isCreating)
                    .padding(.horizontal, 32)
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
        .onChange(of: sessionCoordinator.isInSession) { _, isInSession in
            if isInSession {
                dismiss()
            }
        }
    }
    
    private var isValidJoinCode: Bool {
        joinCode.count >= 4 && joinCode.count <= 20
    }
    
    private func createSession() {
        isCreating = true
        Task {
            await sessionCoordinator.createSession(joinCode: joinCode)
            isCreating = false
        }
    }
}

#Preview {
    CreateSessionView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
                    baseURL: URL(string: "http://localhost:8000")!,
                    authService: AuthService.mock // Use the mock!
                )))
}


