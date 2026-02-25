//
//  HostControlsView.swift
//  QueueIT
//
//  Host controls with refined Neon Lounge styling
//

import SwiftUI

struct HostControlsView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var isLocked: Bool = false
    @State private var showSkipConfirmation: Bool = false
    @State private var appeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground(showGrid: false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.spacingLg) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.warning.opacity(0.2))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.warning)
                            }
                            .scaleEffect(appeared ? 1 : 0.8)
                            .opacity(appeared ? 1 : 0)
                            
                            Text("Host Controls")
                                .font(AppTheme.title())
                                .foregroundColor(.white)
                            
                            Text("Manage your session")
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        
                        VStack(spacing: 14) {
                            Button(action: { showSkipConfirmation = true }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(AppTheme.coral)
                                    }
                                    Text("Skip Current Track")
                                        .font(AppTheme.headline())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(AppTheme.spacing)
                                .frostedCard()
                            }
                            .buttonStyle(.plain)
                            .disabled(sessionCoordinator.nowPlaying == nil)
                            .opacity(sessionCoordinator.nowPlaying == nil ? 0.5 : 1)
                            
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(isLocked ? AppTheme.coral : AppTheme.neonCyan)
                                }
                                Text("Lock Queue")
                                    .font(AppTheme.headline())
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $isLocked)
                                    .labelsHidden()
                                    .tint(AppTheme.neonCyan)
                            }
                            .padding(AppTheme.spacing)
                            .frostedCard()
                            .onChange(of: isLocked) { _, newValue in
                                Task {
                                    await sessionCoordinator.toggleLock(locked: newValue)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Session Code")
                                        .font(AppTheme.caption())
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                    if let joinCode = sessionCoordinator.currentSession?.session.joinCode {
                                        Text(joinCode)
                                            .font(AppTheme.mono())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                HStack {
                                    Text("Queue Size")
                                        .font(AppTheme.caption())
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                    Text("\(sessionCoordinator.queue.count) songs")
                                        .font(AppTheme.body())
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(AppTheme.spacing)
                            .frostedCard()
                        }
                        .padding(.horizontal, AppTheme.spacing)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
        .confirmationDialog(
            "Skip Current Track?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip", role: .destructive) {
                Task {
                    await sessionCoordinator.skipCurrentTrack()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately skip to the next song in the queue.")
        }
    }
}

#Preview {
    HostControlsView()
        .environmentObject(SessionCoordinator(apiService: QueueAPIService(
            baseURL: URL(string: "http://localhost:8000")!,
            authService: AuthService.mock
        )))
}
