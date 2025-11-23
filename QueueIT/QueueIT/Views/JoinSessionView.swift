//
//  JoinSessionView.swift
//  QueueIT
//
//  Join an existing session with a code
//

import SwiftUI

struct JoinSessionView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode: String = ""
    @State private var isJoining: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.darkGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Icon and title
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.secondaryGradient)
                        
                        Text("Join the Party")
                            .font(AppTheme.title())
                            .foregroundColor(.white)
                        
                        Text("Enter the session code from your host")
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
                        
                        TextField("Enter session code", text: $joinCode)
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
                    
                    // Join button
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
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    
                    // QR Code scanner button (placeholder)
                    Button(action: {
                        // TODO: Implement QR code scanner
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code")
                        }
                        .font(AppTheme.body())
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                    }
                    
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


