//
//  GuestNamePromptView.swift
//  QueueITClip
//
//  One-time "What's your name?" sheet shown on first App Clip launch.
//  The chosen name appears in the queue as "Added by <name>".
//

import SwiftUI

struct GuestNamePromptView: View {
    @Binding var isPresented: Bool
    /// Called when the user confirms a name; the name has already been saved to AppClipGuestName.
    var onConfirm: ((String) -> Void)?

    @State private var name: String = AppClipGuestName.randomFunName
    @State private var appeared = false

    var body: some View {
        ZStack {
            NeonBackground(showGrid: false)

            VStack(spacing: AppTheme.spacingLg) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Text("🎉")
                        .font(.system(size: 36))
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("What's your name?")
                        .font(AppTheme.title())
                        .foregroundColor(.white)

                    Text("It shows up in the queue next to your songs.")
                        .font(AppTheme.body())
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .offset(y: appeared ? 0 : 12)
                .opacity(appeared ? 1 : 0)

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    TextField("e.g. Neon Giraffe", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(AppTheme.spacing)
                        .background(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSm)
                                .stroke(AppTheme.neonCyan.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(AppTheme.cornerRadiusSm)
                        .autocorrectionDisabled()

                    Button(action: rollName) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12))
                            Text("Give me a random name")
                                .font(AppTheme.caption())
                        }
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, AppTheme.spacingXl)

                Spacer()

                // CTA
                Button(action: confirm) {
                    Text("Let's Go!")
                        .neonButton(gradient: AppTheme.primaryGradient, isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, AppTheme.spacingXl)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private func rollName() {
        withAnimation(.spring(duration: 0.3)) {
            name = AppClipGuestName.randomFunName
        }
    }

    private func confirm() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        AppClipGuestName.displayName = trimmed
        onConfirm?(trimmed)
        isPresented = false
    }
}

#Preview {
    GuestNamePromptView(isPresented: .constant(true))
}
