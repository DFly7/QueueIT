//
//  JoinSessionView.swift
//  QueueIT
//
//  Join session with refined Neon Lounge styling
//

import SwiftUI

struct JoinSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isJoining: Bool = false
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
                                    .fill(AppTheme.secondaryGradient.opacity(0.2))
                                    .frame(width: 88, height: 88)
                                Image(systemName: "person.2.wave.2.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(AppTheme.secondaryGradient)
                            }
                            .scaleEffect(appeared ? 1 : 0.8)
                            .opacity(appeared ? 1 : 0)
                            
                            Text("Join the Party")
                                .font(AppTheme.title())
                                .foregroundColor(.white)
                            
                            Text("Enter the session code from your host")
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Join Code")
                                .font(AppTheme.caption())
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextField("Enter session code", text: $joinCode)
                                .textFieldStyle(.plain)
                                .font(AppTheme.mono())
                                .foregroundColor(.white)
                                .padding(AppTheme.spacing)
                                .background(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                                        .stroke(
                                            !joinCode.isEmpty ? AppTheme.coral.opacity(0.5) : Color.white.opacity(0.1),
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
                        
                        Button(action: joinSession) {
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: AppTheme.buttonHeight)
                            } else {
                                Text("Join Session")
                                    .neonButton(
                                        gradient: AppTheme.secondaryGradient,
                                        isEnabled: isValidJoinCode
                                    )
                            }
                        }
                        .disabled(!isValidJoinCode || isJoining)
                        .padding(.horizontal, AppTheme.spacingXl)
                        .padding(.top, 8)
                        
                        Button(action: { /* TODO: QR scanner */ }) {
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 18))
                                Text("Scan QR Code")
                                    .font(AppTheme.body())
                            }
                            .foregroundColor(.white.opacity(0.6))
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
