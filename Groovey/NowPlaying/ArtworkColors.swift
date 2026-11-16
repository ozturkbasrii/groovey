import AppKit
import SwiftUI

/// Two colours pulled from album art, used to tint the scene's lighting.
struct ArtworkPalette: Equatable {
    /// The most vivid colour in the cover.
    var accent: Color
    /// The overall average colour.
    var average: Color

    static let neutral = ArtworkPalette(
        accent: Color(red: 0.96, green: 0.62, blue: 0.30),
        average: Color(red: 0.45, green: 0.36, blue: 0.30)
    )

    init(accent: Color, average: Color) {
        self.accent = accent
        self.average = average
    }

    init?(image: NSImage) {
        let side = 24
        guard
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)

        var sum = (r: 0.0, g: 0.0, b: 0.0)
        var best = (score: -1.0, r: 0.0, g: 0.0, b: 0.0)
        for index in 0..<(side * side) {
            let r = Double(pixels[index * 4]) / 255
            let g = Double(pixels[index * 4 + 1]) / 255
            let b = Double(pixels[index * 4 + 2]) / 255
            sum.r += r; sum.g += g; sum.b += b

            let high = max(r, g, b), low = min(r, g, b)
            let saturation = high == 0 ? 0 : (high - low) / high
            // Favour colours that are both saturated and reasonably bright.
            let score = saturation * (0.35 + 0.65 * high)
            if score > best.score { best = (score, r, g, b) }
        }

        let count = Double(side * side)
        average = Color(red: sum.r / count, green: sum.g / count, blue: sum.b / count)
        // A nearly grey cover has no meaningful accent; keep the warm default.
        accent = best.score > 0.18 ? Color(red: best.r, green: best.g, blue: best.b) : ArtworkPalette.neutral.accent
    }
}
