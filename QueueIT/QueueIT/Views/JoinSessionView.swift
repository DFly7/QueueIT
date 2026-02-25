//
//  JoinSessionView.swift
//  QueueIT
//
//  Join session with refined form and visual hierarchy
//

import SwiftUI

struct JoinSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isJoining: Bool = false
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
                                    .fill(AppTheme.accentSecondary.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.2.wave.2.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(AppTheme.accentSecondary)
                            }
                            
                            Text("Join the Party")
                                .font(AppTheme.largeTitle())
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Enter the session code from your host")
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
                            
                            TextField("Enter session code", text: $joinCode)
                                .textFieldStyle(.plain)
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(AppTheme.spacingM)
                                .background(AppTheme.surface)
                                .cornerRadius(AppTheme.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                        .stroke(joinCode.isEmpty ? AppTheme.textMuted.opacity(0.3) : AppTheme.accentSecondary.opacity(0.5), lineWidth: 1)
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
                        
                        // Join button
                        Button(action: joinSession) {
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: AppTheme.buttonHeight)
                            } else {
                                Text("Join Session")
                                    .secondaryButton(isEnabled: isValidJoinCode)
                            }
                        }
                        .disabled(!isValidJoinCode || isJoining)
                        .padding(.horizontal, AppTheme.spacingXL)
                        .padding(.top, AppTheme.spacingS)
                        .opacity(contentOpacity)
                        
                        // QR placeholder
                        Button(action: { /* TODO: QR scanner */ }) {
                            HStack(spacing: AppTheme.spacingS) {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan QR Code")
                            }
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(AppTheme.spacingM)
                        }
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
