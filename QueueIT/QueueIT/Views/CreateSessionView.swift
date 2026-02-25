//
//  CreateSessionView.swift
//  QueueIT
//
//  Create session with refined form and visual hierarchy
//

import SwiftUI

struct CreateSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isCreating: Bool = false
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.spacingL) {
                        Spacer()
                            .frame(height: AppTheme.spacingM)
                        
                        // Hero
                        VStack(spacing: AppTheme.spacingM) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 44))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            
                            Text("Create Your Session")
                                .font(AppTheme.largeTitle())
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Choose a unique join code that your friends can use")
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppTheme.spacingXL)
                        }
                        .opacity(contentOpacity)
                        
                        // Form
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Join Code")
                                .font(AppTheme.caption())
                                .foregroundColor(AppTheme.textSecondary)
                            
                            TextField("Enter code (4-20 characters)", text: $joinCode)
                                .textFieldStyle(.plain)
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(AppTheme.spacingM)
                                .background(AppTheme.surface)
                                .cornerRadius(AppTheme.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                        .stroke(joinCode.isEmpty ? AppTheme.textMuted.opacity(0.3) : AppTheme.accent.opacity(0.5), lineWidth: 1)
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.horizontal, AppTheme.spacingXL)
                        .opacity(contentOpacity)
                        
                        if let error = sessionCoordinator.error {
                            HStack(spacing: AppTheme.spacingS) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text(error)
                                    .font(AppTheme.caption())
                                    .foregroundColor(AppTheme.error)
                            }
                            .padding(.horizontal, AppTheme.spacingXL)
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
                                    .primaryButton(isEnabled: isValidJoinCode)
                            }
                        }
                        .disabled(!isValidJoinCode || isCreating)
                        .padding(.horizontal, AppTheme.spacingXL)
                        .padding(.top, AppTheme.spacingS)
                        .opacity(contentOpacity)
                        
                        Spacer()
                            .frame(height: AppTheme.spacingXL)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(AppTheme.headline())
                }
            }
        }
        .onAppear {
            withAnimation(AppTheme.smoothAnimation) { contentOpacity = 1 }
        }
        .onChange(of: sessionCoordinator.isInSession) { _, isInSession in
            if isInSession { dismiss() }
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
