import AppKit
import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case warmRoom, night, minimal

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .warmRoom: return "Warm Room"
        case .night: return "Night"
        case .minimal: return "Minimal"
        }
    }

    var style: SceneStyle {
        switch self {
        case .warmRoom:
            return SceneStyle(
                wallTop: Color(hex: 0x6E4A3A), wallBottom: Color(hex: 0xB07A55),
                deskBack: Color(hex: 0x5A2E17), deskFront: Color(hex: 0x2E1509),
                woodLight: Color(hex: 0x8A5632), woodDark: Color(hex: 0x4A2A15),
                deckLight: Color(hex: 0xEFE6D8), deckDark: Color(hex: 0xCDBFAB),
                text: Color(hex: 0xF6E7D0),
                hasLamp: true, hasLightBar: false, accentGlow: 0.16, vignette: 0.55
            )
        case .night:
            return SceneStyle(
                wallTop: Color(hex: 0x0B0D17), wallBottom: Color(hex: 0x1A1D2E),
                deskBack: Color(hex: 0x15131B), deskFront: Color(hex: 0x07060A),
                woodLight: Color(hex: 0x2B2A33), woodDark: Color(hex: 0x131218),
                deckLight: Color(hex: 0x34343E), deckDark: Color(hex: 0x1D1D25),
                text: Color(hex: 0xE4E6F2),
                hasLamp: false, hasLightBar: true, accentGlow: 0.42, vignette: 0.7
            )
        case .minimal:
            return SceneStyle(
                wallTop: Color(hex: 0x1C1C1E), wallBottom: Color(hex: 0x0E0E10),
                deskBack: Color(hex: 0x1C1C1E), deskFront: Color(hex: 0x0E0E10),
                woodLight: Color(hex: 0x2A2A2E), woodDark: Color(hex: 0x151517),
                deckLight: Color(hex: 0x2C2C30), deckDark: Color(hex: 0x1A1A1D),
                text: Color(hex: 0xF2F2F4),
                hasLamp: false, hasLightBar: false, accentGlow: 0.3, vignette: 0.6
            )
        }
    }
}

struct SceneStyle {
    var wallTop: Color
    var wallBottom: Color
    var deskBack: Color
    var deskFront: Color
    /// Turntable plinth sides.
    var woodLight: Color
    var woodDark: Color
    /// Turntable top plate.
    var deckLight: Color
    var deckDark: Color
    var text: Color
    var hasLamp: Bool
    var hasLightBar: Bool
    /// How strongly the album's accent colour washes over the wall.
    var accentGlow: Double
    var vignette: Double
}

/// Where things sit on the 1440×900 stage that every scene is composed on.
enum StageLayout {
    static let size = CGSize(width: 1440, height: 900)
    /// The line where the wall meets the desk.
    static let deskLine: CGFloat = 470
    static let turntable = CGPoint(x: 640, y: 628)
    static let coverStand = CGPoint(x: 1092, y: 450)
    static let lamp = CGPoint(x: 252, y: 412)
    static let pile = CGRect(x: 1040, y: 690, width: 250, height: 120)

    /// Scale and centre of the top-down turntable in the Minimal scene.
    static let minimalScale: CGFloat = 1.3
    static let minimalTurntable = CGPoint(x: 720, y: 405)

    /// Where the record's label sits in `container`, for the layer that spins it.
    static func label(theme: Theme, in container: CGSize) -> (center: CGPoint, diameter: CGFloat, squash: CGFloat) {
        let labelDiameter = TurntableTop.recordDiameter * RecordView.labelRatio
        let spindle = TonearmGeometry.spindle
        let center: CGPoint, diameter: CGFloat, squash: CGFloat
        if theme == .minimal {
            center = CGPoint(
                x: minimalTurntable.x + (spindle.x - TurntableTop.size.width / 2) * minimalScale,
                y: minimalTurntable.y + (spindle.y - TurntableTop.size.height / 2) * minimalScale
            )
            diameter = labelDiameter * minimalScale
            squash = 1
        } else {
            squash = TurntableView.squash
            let height = TurntableTop.size.height * squash + TurntableView.frontHeight
            center = CGPoint(
                x: turntable.x - TurntableTop.size.width / 2 + spindle.x,
                y: turntable.y - height / 2 + spindle.y * squash
            )
            diameter = labelDiameter
        }
        let scale = scale(for: container)
        let origin = origin(for: container)
        return (CGPoint(x: origin.x + center.x * scale, y: origin.y + center.y * scale), diameter * scale, squash)
    }

    static func scale(for container: CGSize) -> CGFloat {
        min(container.width / size.width, container.height / size.height)
    }

    static func origin(for container: CGSize) -> CGPoint {
        let scale = scale(for: container)
        return CGPoint(x: (container.width - size.width * scale) / 2, y: (container.height - size.height * scale) / 2)
    }

    /// Converts a rectangle in stage units to the container's coordinates (top-left origin).
    static func rect(_ stageRect: CGRect, in container: CGSize) -> CGRect {
        let scale = scale(for: container)
        let origin = origin(for: container)
        return CGRect(
            x: origin.x + stageRect.minX * scale, y: origin.y + stageRect.minY * scale,
            width: stageRect.width * scale, height: stageRect.height * scale
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private var rgb: (r: Double, g: Double, b: Double) {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return (Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
    }

    /// Linear mix towards `other`; 0 keeps this colour, 1 returns `other`.
    func blended(with other: Color, amount: Double) -> Color {
        let a = rgb, b = other.rgb
        let t = min(1, max(0, amount))
        return Color(red: a.r + (b.r - a.r) * t, green: a.g + (b.g - a.g) * t, blue: a.b + (b.b - a.b) * t)
    }

    func darkened(_ amount: Double) -> Color {
        blended(with: .black, amount: amount)
    }
}
