//
//  AccountSheet.swift
//  QueueIT
//
//  Account management: sign out and delete account.
//

import SwiftUI

struct AccountSheet: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                // Avatar + username
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient.opacity(0.25))
                            .frame(width: 72, height: 72)
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }

                    VStack(spacing: 4) {
                        Text(authService.currentUser?.username ?? "Account")
                            .font(AppTheme.headline())
                            .foregroundColor(.white)

                        if let email = authService.currentUser?.email {
                            Text(email)
                                .font(AppTheme.caption())
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.bottom, 36)

                // Actions
                VStack(spacing: 12) {
                    // Sign Out
                    Button(action: {
                        authService.signOut()
                        dismiss()
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.neonCyan)
                                .frame(width: 28)
                            Text("Sign Out")
                                .font(AppTheme.headline())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(AppTheme.spacingLg)
                        .frostedCard()
                    }
                    .buttonStyle(.plain)

                    // Delete Account
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack(spacing: 14) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.coral)
                                .frame(width: 28)
                            Text("Delete Account")
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.coral)
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(AppTheme.coral)
                            }
                        }
                        .padding(AppTheme.spacingLg)
                        .frostedCard()
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.coral.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeletingAccount)
                }
                .padding(.horizontal, AppTheme.spacingXl)

                // Error message
                if let deleteError {
                    Text(deleteError)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.spacingXl)
                        .padding(.top, 12)
                }

                // Sign in with Apple note
                Text("If you signed in with Apple, revoke access via\nSettings → Apple ID → Sign-In & Security → Apps Using Apple ID.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacingXl)
                    .padding(.top, 28)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text("Permanently delete your account and all data? This cannot be undone.")
        }
    }

    private func performDelete() async {
        isDeletingAccount = true
        deleteError = nil
        do {
            try await authService.deleteAccount()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeletingAccount = false
    }
}

#Preview {
    AccountSheet()
        .environmentObject(AuthService.mock)
}
