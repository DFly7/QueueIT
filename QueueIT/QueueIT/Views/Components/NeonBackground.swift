//
//  NeonBackground.swift
//  QueueIT
//
//  Reusable atmospheric background with mesh gradient and subtle grid
//

import SwiftUI

struct NeonBackground: View {
    var showGrid: Bool = true
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            AppTheme.backgroundGradient
                .ignoresSafeArea()
            
            AppTheme.meshGradient
                .ignoresSafeArea()
            
            if showGrid {
                GeometryReader { geo in
                    Path { path in
                        let spacing: CGFloat = 40
                        for i in stride(from: 0, through: geo.size.width + geo.size.height, by: spacing) {
                            path.move(to: CGPoint(x: i, y: 0))
                            path.addLine(to: CGPoint(x: i, y: geo.size.height))
                            path.move(to: CGPoint(x: 0, y: i))
                            path.addLine(to: CGPoint(x: geo.size.width, y: i))
                        }
                    }
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
                }
                .ignoresSafeArea()
            }
        }
    }
}

struct VinylRing: View {
    let size: CGFloat
    var opacity: Double = 0.15
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [AppTheme.neonCyan.opacity(opacity), AppTheme.violet.opacity(opacity * 0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        NeonBackground()
        Text("Preview")
            .foregroundColor(.white)
    }
}
