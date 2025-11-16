//
//  AppTheme.swift
//  QueueIT
//
//  Party-ready design system with vibrant colors and smooth animations
//

import SwiftUI

struct AppTheme {
    // MARK: - Colors
    
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "FF6B9D"), Color(hex: "C06FFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [Color(hex: "00C9FF"), Color(hex: "92FE9D")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let darkGradient = LinearGradient(
        colors: [Color(hex: "141E30"), Color(hex: "243B55")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accent = Color(hex: "FF6B9D")
    static let accentSecondary = Color(hex: "C06FFF")
    static let success = Color(hex: "92FE9D")
    static let warning = Color(hex: "FFD93D")
    
    // MARK: - Typography
    
    static func largeTitle() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }
    
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
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
    
    // MARK: - Spacing
    
    static let spacing: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 56
    
    // MARK: - Animations
    
    static let quickAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.7)
    static let smoothAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    static let bouncyAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
            .background(isEnabled ? gradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(AppTheme.cornerRadius)
            .shadow(color: isEnabled ? Color.black.opacity(0.2) : Color.clear, radius: 8, y: 4)
    }
}

extension View {
    func gradientButton(gradient: LinearGradient = AppTheme.primaryGradient, isEnabled: Bool = true) -> some View {
        modifier(GradientButtonStyle(gradient: gradient, isEnabled: isEnabled))
    }
    
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(AppTheme.cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 2)
    }
}


