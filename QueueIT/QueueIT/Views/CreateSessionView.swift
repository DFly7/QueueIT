//
//  CreateSessionView.swift
//  QueueIT
//
//  Create session with secret-code aesthetic
//

import SwiftUI

struct CreateSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isCreating: Bool = false
    @FocusState private var isCodeFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.ambientGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 56))
                                .foregroundStyle(AppTheme.primaryGradient)
                            
                            Text("Create Session")
                                .font(AppTheme.largeTitle())
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Pick a code your friends will use to join")
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 24)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("JOIN CODE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.textMuted)
                                .tracking(1.2)
                            
                            TextField("e.g. PARTY2024", text: $joinCode)
                                .textFieldStyle(.plain)
                                .font(AppTheme.monoCode())
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(18)
                                .background(AppTheme.surfaceCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCodeFocused ? AppTheme.accentPrimary.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.5)
                                )
                                .cornerRadius(12)
                                .autocapitalization(.characters)
                                .disableAutocorrection(true)
                                .focused($isCodeFocused)
                        }
                        .padding(.horizontal, 24)
                        
                        if let error = sessionCoordinator.error {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.destructive)
                                Text(error)
                                    .font(AppTheme.caption())
                                    .foregroundColor(AppTheme.destructive)
                            }
                            .padding(.horizontal, 24)
                        }
                        
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
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentPrimary)
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
            authService: AuthService.mock
        )))
}
