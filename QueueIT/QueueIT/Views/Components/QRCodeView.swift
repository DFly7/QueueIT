//
//  QRCodeView.swift
//  QueueIT
//
//  Generates a QR code from any string using CoreImage.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200
    var foregroundColor: Color = .white
    var backgroundColor: Color = .clear

    var body: some View {
        if let image = generateQRCode(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Fallback if generation fails
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.white.opacity(0.3))
                )
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Colorize: replace black → foreground, white → background
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = ciImage
        colorFilter.color0 = CIColor(color: UIColor(foregroundColor))
        colorFilter.color1 = CIColor(color: UIColor(backgroundColor))

        guard let coloredImage = colorFilter.outputImage else { return nil }

        // Scale up for crisp rendering
        let scale = size / ciImage.extent.width
        let scaledImage = coloredImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    ZStack {
        Color.black
        QRCodeView(
            content: "https://queueit.app/join?code=PARTY123",
            size: 220,
            foregroundColor: .white,
            backgroundColor: .black
        )
    }
}
