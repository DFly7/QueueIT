//
//  AppTheme.swift
//  QueueIT
//
//  Neo-brutalist design system: bold, raw, unforgettable
//

import SwiftUI

struct AppTheme {
    // MARK: - Colors (Neo-brutalist palette)
    
    static let background = Color(hex: "0A0A0B")
    static let surface = Color(hex: "141416")
    static let surfaceElevated = Color(hex: "1C1C1F")
    
    static let accent = Color(hex: "FF6B35")      // Electric orange
    static let accentSecondary = Color(hex: "00D4AA")  // Mint/teal
    static let accentTertiary = Color(hex: "FFD93D")  // Gold (host/premium)
    
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "A1A1A6")
    static let textMuted = Color(hex: "6E6E73")
    
    static let success = Color(hex: "34D399")
    static let warning = Color(hex: "FFD93D")
    static let error = Color(hex: "FF6B6B")
    
    // Gradients (used sparingly for hero moments)
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "FF6B35"), Color(hex: "FF8F65")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [Color(hex: "00D4AA"), Color(hex: "00F5C4")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "FFD93D"), Color(hex: "FFE566")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Typography (Bold, distinctive)
    
    static func displayLarge() -> Font {
        .system(size: 42, weight: .black, design: .rounded)
    }
    
    static func display() -> Font {
        .system(size: 32, weight: .heavy, design: .rounded)
    }
    
    static func largeTitle() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    static func title() -> Font {
        .system(size: 22, weight: .bold, design: .rounded)
    }
    
    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .rounded)
    }
    
    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .rounded)
    }
    
    static func caption() -> Font {
        .system(size: 13, weight: .medium, design: .rounded)
    }
    
    static func mono() -> Font {
        .system(size: 18, weight: .bold, design: .monospaced)
    }
    
    // MARK: - Spacing & Layout
    
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    static let cornerRadiusS: CGFloat = 8
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusL: CGFloat = 20
    
    static let buttonHeight: CGFloat = 56
    static let buttonHeightCompact: CGFloat = 48
    
    // MARK: - Animations
    
    static let quickAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.75)
    static let smoothAnimation: Animation = .spring(response: 0.45, dampingFraction: 0.8)
    static let bouncyAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.6)
    static let slowAnimation: Animation = .easeInOut(duration: 0.5)
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct PrimaryButtonStyle: ViewModifier {
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isEnabled ? AppTheme.accent : AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isEnabled ? Color.clear : AppTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
    }
}

struct SecondaryButtonStyle: ViewModifier {
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headline())
            .foregroundColor(isEnabled ? AppTheme.accentSecondary : AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isEnabled ? AppTheme.accentSecondary.opacity(0.5) : Color.clear, lineWidth: 2)
            )
    }
}

extension View {
    func primaryButton(isEnabled: Bool = true) -> some View {
        modifier(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    func secondaryButton(isEnabled: Bool = true) -> some View {
        modifier(SecondaryButtonStyle(isEnabled: isEnabled))
    }
    
    func cardStyle() -> some View {
        self
            .background(AppTheme.surface)
            .cornerRadius(AppTheme.cornerRadius)
    }
    
    func glassCard() -> some View {
        self
            .background(AppTheme.surface.opacity(0.6))
            .background(.ultraThinMaterial.opacity(0.3))
            .cornerRadius(AppTheme.cornerRadius)
    }
}
