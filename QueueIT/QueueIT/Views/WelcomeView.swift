//
//  WelcomeView.swift
//  QueueIT
//
//  Bold welcome with asymmetric layout and staggered entry
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @State private var showingCreateSession = false
    @State private var showingJoinSession = false
    @State private var createOffset: CGFloat = 60
    @State private var joinOffset: CGFloat = 60
    @State private var headerOpacity: Double = 0
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 48
                    for x in stride(from: 0, to: geo.size.width + step, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                }
                .stroke(AppTheme.textMuted.opacity(0.06), lineWidth: 0.5)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Header
                VStack(spacing: AppTheme.spacingS) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(AppTheme.accent)
                        .opacity(headerOpacity)
                    
                    Text("QueueUp")
                        .font(AppTheme.display())
                        .foregroundColor(AppTheme.textPrimary)
                        .opacity(headerOpacity)
                    
                    Text("Collaborative music sessions")
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textSecondary)
                        .opacity(headerOpacity)
                }
                .padding(.bottom, AppTheme.spacingXL)
                
                // Action buttons - asymmetric layout
                VStack(spacing: AppTheme.spacingM) {
                    Button(action: {
                        withAnimation(AppTheme.quickAnimation) { showingCreateSession = true }
                    }) {
                        HStack(spacing: AppTheme.spacingS) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Create Session")
                        }
                        .primaryButton()
                    }
                    .offset(x: createOffset)
                    .padding(.leading, AppTheme.spacingM)
                    .padding(.trailing, AppTheme.spacingXL)
                    
                    Button(action: {
                        withAnimation(AppTheme.quickAnimation) { showingJoinSession = true }
                    }) {
                        HStack(spacing: AppTheme.spacingS) {
                            Image(systemName: "person.2.fill")
                                .font(.title2)
                            Text("Join Session")
                        }
                        .secondaryButton()
                    }
                    .offset(x: -joinOffset)
                    .padding(.leading, AppTheme.spacingXL)
                    .padding(.trailing, AppTheme.spacingM)
                }
                .padding(.bottom, AppTheme.spacingXL)
                
                Spacer()
                
                // User footer
                if let user = authService.currentUser {
                    VStack(spacing: AppTheme.spacingS) {
                        Text("Signed in as")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Text(user.username ?? "User")
                            .font(AppTheme.headline())
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Button("Sign Out") {
                            authService.signOut()
                        }
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.accent)
                        .padding(.top, AppTheme.spacingXS)
                    }
                    .padding(.bottom, AppTheme.spacingXL)
                }
            }
        }
        .onAppear {
            withAnimation(AppTheme.smoothAnimation) {
                headerOpacity = 1
                createOffset = 0
            }
            withAnimation(AppTheme.smoothAnimation.delay(0.1)) {
                joinOffset = 0
            }
        }
        .sheet(isPresented: $showingCreateSession) {
            CreateSessionView()
                .environmentObject(sessionCoordinator)
        }
        .sheet(isPresented: $showingJoinSession) {
            JoinSessionView()
                .environmentObject(sessionCoordinator)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.mock)
        .environmentObject(SessionCoordinator.mock())
}
