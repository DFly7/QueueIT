//
//  AppTheme.swift
//  QueueIT
//
//  "Neon Club" design system — electric cyan, warm amber, inky depth
//

import SwiftUI

struct AppTheme {
    // MARK: - Colors
    
    static let surface = Color(hex: "0A0A0F")
    static let surfaceElevated = Color(hex: "12121A")
    static let surfaceCard = Color(hex: "1A1A24")
    
    static let accentPrimary = Color(hex: "00D4FF")   // Electric cyan
    static let accentSecondary = Color(hex: "FF9F43")   // Warm amber
    static let accentTertiary = Color(hex: "7B68EE")   // Soft violet
    static let success = Color(hex: "00E676")
    static let warning = Color(hex: "FFB74D")
    static let destructive = Color(hex: "FF5252")
    
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.5)
    
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "00D4FF"), Color(hex: "00A8CC")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [Color(hex: "FF9F43"), Color(hex: "FF6B35")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let ambientGradient = LinearGradient(
        colors: [
            Color(hex: "0A0A0F"),
            Color(hex: "12121A"),
            Color(hex: "0D1520")
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let darkGradient = LinearGradient(
        colors: [Color(hex: "0A0A0F"), Color(hex: "12121A")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accent = accentPrimary
    
    static let glowGradient = RadialGradient(
        colors: [
            Color(hex: "00D4FF").opacity(0.15),
            Color(hex: "00D4FF").opacity(0.05),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 300
    )
    
    // MARK: - Typography
    
    static func displayTitle() -> Font {
        .system(size: 36, weight: .bold, design: .rounded)
    }
    
    static func largeTitle() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    static func title() -> Font {
        .system(size: 22, weight: .semibold, design: .rounded)
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
    
    static func monoCode() -> Font {
        .system(size: 18, weight: .bold, design: .monospaced)
    }
    
    // MARK: - Spacing & Layout
    
    static let spacing: CGFloat = 16
    static let spacingLg: CGFloat = 24
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusLg: CGFloat = 24
    static let buttonHeight: CGFloat = 56
    
    // MARK: - Animations
    
    static let quickAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.75)
    static let smoothAnimation: Animation = .spring(response: 0.45, dampingFraction: 0.8)
    static let bouncyAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.6)
    static let staggeredDelay: Double = 0.05
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

struct GradientButtonStyle: ViewModifier {
    let gradient: LinearGradient
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isEnabled ? gradient : LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isEnabled ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isEnabled ? AppTheme.accentPrimary.opacity(0.3) : Color.clear, radius: 12, y: 4)
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.surfaceCard.opacity(0.8))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

extension View {
    func gradientButton(gradient: LinearGradient = AppTheme.primaryGradient, isEnabled: Bool = true) -> some View {
        modifier(GradientButtonStyle(gradient: gradient, isEnabled: isEnabled))
    }
    
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
    
    func cardStyle() -> some View {
        self
            .background(AppTheme.surfaceCard)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
