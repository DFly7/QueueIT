//
//  AppTheme.swift
//  QueueIT
//
//  Neon Lounge design system — retro-futuristic, club-inspired, electric
//

import SwiftUI

struct AppTheme {
    // MARK: - Colors
    
    static let background = Color(hex: "0A0A0F")
    static let surface = Color(hex: "12121A")
    static let surfaceElevated = Color(hex: "1A1A24")
    
    static let neonCyan = Color(hex: "00E5CC")
    static let neonCyanDim = Color(hex: "00E5CC").opacity(0.6)
    static let coral = Color(hex: "FF6B4A")
    static let violet = Color(hex: "8B5CF6")
    static let gold = Color(hex: "FFD93D")
    
    static let primaryGradient = LinearGradient(
        colors: [neonCyan, Color(hex: "00B8A3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [coral, Color(hex: "FF8F73")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [violet, Color(hex: "A78BFA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "0A0A0F"),
            Color(hex: "0D0D14"),
            Color(hex: "0A0A0F")
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let meshGradient = RadialGradient(
        colors: [
            neonCyan.opacity(0.08),
            violet.opacity(0.04),
            Color.clear
        ],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 400
    )
    
    static let accent = neonCyan
    static let accentSecondary = coral
    static let success = Color(hex: "34D399")
    static let warning = gold
    
    // MARK: - Typography
    
    static func displayTitle() -> Font {
        .system(size: 42, weight: .black, design: .rounded)
    }
    
    static func largeTitle() -> Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }
    
    static func title() -> Font {
        .system(size: 24, weight: .bold, design: .rounded)
    }
    
    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .rounded)
    }
    
    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }
    
    static func caption() -> Font {
        .system(size: 13, weight: .medium, design: .rounded)
    }
    
    static func mono() -> Font {
        .system(size: 18, weight: .semibold, design: .monospaced)
    }
    
    static func monoSmall() -> Font {
        .system(size: 14, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Spacing & Layout
    
    static let spacing: CGFloat = 16
    static let spacingLg: CGFloat = 24
    static let spacingXl: CGFloat = 32
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSm: CGFloat = 12
    static let cornerRadiusLg: CGFloat = 24
    static let buttonHeight: CGFloat = 56
    
    // MARK: - Animations
    
    static let quickAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.75)
    static let smoothAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    static let bouncyAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.6)
    static let slowAnimation: Animation = .easeInOut(duration: 0.6)
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

struct NeonButtonStyle: ViewModifier {
    let gradient: LinearGradient
    let isEnabled: Bool
    let glow: Bool
    
    init(gradient: LinearGradient, isEnabled: Bool, glow: Bool = true) {
        self.gradient = gradient
        self.isEnabled = isEnabled
        self.glow = glow
    }
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.buttonHeight)
            .background(
                ZStack {
                    if isEnabled && glow {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .fill(gradient.opacity(0.4))
                            .blur(radius: 12)
                            .offset(y: 2)
                    }
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .fill(isEnabled ? gradient : LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isEnabled ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct FrostedCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func neonButton(gradient: LinearGradient = AppTheme.primaryGradient, isEnabled: Bool = true, glow: Bool = true) -> some View {
        modifier(NeonButtonStyle(gradient: gradient, isEnabled: isEnabled, glow: glow))
    }
    
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
    
    func frostedCard() -> some View {
        modifier(FrostedCardStyle())
    }
}
