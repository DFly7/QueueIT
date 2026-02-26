//
//  CreateSessionView.swift
//  QueueIT
//
//  Create session with refined Neon Lounge styling
//

import SwiftUI

struct CreateSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isCreating: Bool = false
    @State private var appeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground(showGrid: false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.spacingLg) {
                        Spacer(minLength: 24)
                        
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primaryGradient.opacity(0.2))
                                    .frame(width: 88, height: 88)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                            .scaleEffect(appeared ? 1 : 0.8)
                            .opacity(appeared ? 1 : 0)
                            
                            Text("Create Your Session")
                                .font(AppTheme.title())
                                .foregroundColor(.white)
                            
                            Text("Choose a unique join code that your friends can use")
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Join Code")
                                .font(AppTheme.caption())
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextField("Enter code (4-20 characters)", text: $joinCode)
                                .textFieldStyle(.plain)
                                .font(AppTheme.mono())
                                .foregroundColor(.white)
                                .padding(AppTheme.spacing)
                                .background(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                                        .stroke(
                                            isValidJoinCode ? AppTheme.neonCyan.opacity(0.5) : Color.white.opacity(0.1),
                                            lineWidth: 1
                                        )
                                )
                                .cornerRadius(AppTheme.cornerRadiusSm)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.horizontal, AppTheme.spacingXl)
                        .padding(.top, 8)
                        
                        if let error = sessionCoordinator.error {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppTheme.coral)
                                Text(error)
                                    .font(AppTheme.caption())
                                    .foregroundColor(AppTheme.coral)
                            }
                            .padding(.horizontal, AppTheme.spacingXl)
                        }
                        
                        Button(action: createSession) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: AppTheme.buttonHeight)
                            } else {
                                Text("Create Session")
                                    .neonButton(
                                        gradient: AppTheme.primaryGradient,
                                        isEnabled: isValidJoinCode
                                    )
                            }
                        }
                        .disabled(!isValidJoinCode || isCreating)
                        .padding(.horizontal, AppTheme.spacingXl)
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
                    .foregroundColor(AppTheme.neonCyan)
                    .font(AppTheme.headline())
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
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
