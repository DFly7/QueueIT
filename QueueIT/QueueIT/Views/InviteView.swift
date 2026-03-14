//
//  InviteView.swift
//  QueueIT
//
//  Host invite sheet: shows a QR code and share link so guests can join
//  without installing the full app.
//

import SwiftUI

struct InviteView: View {
    let joinCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var codeCopied = false

    // Prefer a registered Universal Link; fall back to the default App Clip link
    // while the domain / AASA is not yet live.
    private var joinURL: String {
        "https://appclip.apple.com/id?p=com.yourcompany.queueit.Clip&code=\(joinCode)"
        // Once you have a domain, swap to:
        // "https://queueit.app/join?code=\(joinCode)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                NeonBackground(showGrid: false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.spacingLg) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primaryGradient.opacity(0.2))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                            .scaleEffect(appeared ? 1 : 0.8)
                            .opacity(appeared ? 1 : 0)

                            Text("Invite Friends")
                                .font(AppTheme.title())
                                .foregroundColor(.white)

                            Text("Scan the QR code or share the link.\nNo app install needed.")
                                .font(AppTheme.body())
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        // QR Code card
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .frame(width: 240, height: 240)
                                    .shadow(color: AppTheme.neonCyan.opacity(0.3), radius: 20, y: 4)

                                QRCodeView(
                                    content: joinURL,
                                    size: 200,
                                    foregroundColor: .black,
                                    backgroundColor: .white
                                )
                            }
                            .scaleEffect(appeared ? 1 : 0.9)
                            .opacity(appeared ? 1 : 0)

                            // Session code pill
                            HStack(spacing: 10) {
                                Text("CODE")
                                    .font(AppTheme.caption())
                                    .foregroundColor(.white.opacity(0.4))
                                Text(joinCode)
                                    .font(AppTheme.mono())
                                    .foregroundColor(.white)
                                    .tracking(4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(AppTheme.cornerRadiusSm)
                        }

                        // Action buttons
                        VStack(spacing: 12) {
                            // Share sheet
                            ShareLink(item: joinURL) {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Share Link")
                                        .font(AppTheme.headline())
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: AppTheme.buttonHeight)
                                .background(AppTheme.primaryGradient)
                                .foregroundColor(.white)
                                .cornerRadius(AppTheme.cornerRadius)
                            }

                            // Copy link
                            Button(action: copyLink) {
                                HStack(spacing: 12) {
                                    Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(codeCopied ? "Copied!" : "Copy Link")
                                        .font(AppTheme.headline())
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: AppTheme.buttonHeight)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(codeCopied ? AppTheme.neonCyan : .white)
                                .cornerRadius(AppTheme.cornerRadius)
                                .animation(.spring(duration: 0.3), value: codeCopied)
                            }
                        }
                        .padding(.horizontal, AppTheme.spacingXl)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, AppTheme.spacing)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.neonCyan)
                        .font(AppTheme.headline())
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = joinURL
        withAnimation { codeCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { codeCopied = false }
        }
    }
}

#Preview {
    InviteView(joinCode: "PARTY123")
}
