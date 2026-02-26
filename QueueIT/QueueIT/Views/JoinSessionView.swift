//
//  JoinSessionView.swift
//  QueueIT
//
//  Join session with secret-code aesthetic
//

import SwiftUI

struct JoinSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isJoining: Bool = false
    @FocusState private var isCodeFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.ambientGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 20) {
                            Image(systemName: "person.2.wave.2.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppTheme.secondaryGradient)
                            
                            Text("Join the Party")
                                .font(AppTheme.largeTitle())
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Enter the code from your host")
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 24)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SESSION CODE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.textMuted)
                                .tracking(1.2)
                            
                            TextField("Enter code", text: $joinCode)
                                .textFieldStyle(.plain)
                                .font(AppTheme.monoCode())
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(18)
                                .background(AppTheme.surfaceCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCodeFocused ? AppTheme.accentSecondary.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.5)
                                )
                                .cornerRadius(12)
                                .autocapitalization(.allCharacters)
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
                        
                        Button(action: joinSession) {
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: AppTheme.buttonHeight)
                            } else {
                                Text("Join Session")
                                    .gradientButton(
                                        gradient: AppTheme.secondaryGradient,
                                        isEnabled: isValidJoinCode
                                    )
                            }
                        }
                        .disabled(!isValidJoinCode || isJoining)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        Button(action: { /* TODO: QR scanner */ }) {
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan QR Code")
                                    .font(AppTheme.body())
                            }
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.vertical, 14)
                        }
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
        !joinCode.isEmpty
    }
    
    private func joinSession() {
        isJoining = true
        Task {
            await sessionCoordinator.joinSession(joinCode: joinCode)
            isJoining = false
        }
    }
}

#Preview {
    JoinSessionView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService.mock
        )))
}
