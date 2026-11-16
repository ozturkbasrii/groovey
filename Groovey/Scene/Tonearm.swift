import SwiftUI

/// Tonearm geometry on the turntable's flat top plate (520×420 units).
enum TonearmGeometry {
    static let pivot = CGPoint(x: 456, y: 82)
    static let spindle = CGPoint(x: 222, y: 210)
    /// Pivot to stylus.
    static let length: CGFloat = 250
    static let outerGroove: CGFloat = 166
    static let innerGroove: CGFloat = 84
    /// Stylus distance from the spindle while parked, clear of the record.
    static let restRadius: CGFloat = 220

    /// Direction of the arm, in degrees clockwise from the +x axis, that puts the stylus `radius` away from the spindle.
    static func angle(forStylusRadius radius: CGFloat) -> Double {
        let dx = spindle.x - pivot.x, dy = spindle.y - pivot.y
        let distance = sqrt(dx * dx + dy * dy)
        let toSpindle = atan2(dy, dx)
        let cosine = (length * length + distance * distance - radius * radius) / (2 * length * distance)
        let offset = acos(min(1, max(-1, cosine)))
        return Double(toSpindle - offset) * 180 / .pi
    }

    /// Arm direction for a song `progress` (0...1) of the way through. With no song the arm parks.
    static func angle(progress: Double?, hasTrack: Bool) -> Double {
        guard hasTrack else { return angle(forStylusRadius: restRadius) }
        let clamped = min(1, max(0, progress ?? 0))
        return angle(forStylusRadius: outerGroove + (innerGroove - outerGroove) * clamped)
    }

    static func stylus(atAngle degrees: Double) -> CGPoint {
        let radians: Double = degrees * .pi / 180
        let dx = CGFloat(Double(length) * Darwin.cos(radians))
        let dy = CGFloat(Double(length) * Darwin.sin(radians))
        return CGPoint(x: pivot.x + dx, y: pivot.y + dy)
    }
}

/// Drawn pointing along +x from its centre, then rotated about the pivot.
struct TonearmView: View {
    let angle: Double
    /// Height of the arm above the plate, in plate units. Drawn as an upward shift, which is how
    /// height shows once the plate is foreshortened. Zero for a view from straight above.
    var lift: CGFloat = 0

    private let length = TonearmGeometry.length

    var body: some View {
        let radians = angle * .pi / 180
        // Where the cartridge sits, measured from the pivot.
        let head = CGPoint(x: (length - 12) * CGFloat(Darwin.cos(radians)), y: (length - 12) * CGFloat(Darwin.sin(radians)))

        ZStack {
            pivotBase
            if lift > 0 {
                // Bearing pillar.
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.16), Color(white: 0.3)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 34, height: lift + 34)
                    .offset(y: -lift / 2)
            }
            // The arm floats above the plate, so its shadow falls a little towards the viewer.
            armShadow
                .rotationEffect(.degrees(angle))
                .offset(x: 5, y: 18)
            if lift > 0 {
                // Cartridge, reaching from the headshell down to the groove.
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: lift + 6)
                    .offset(x: head.x, y: head.y - lift / 2)
            }
            arm.rotationEffect(.degrees(angle))
                .offset(y: -lift)
        }
        .frame(width: (length + 90) * 2, height: (length + 90) * 2)
    }

    private var pivotBase: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(white: 0.28), Color(white: 0.08)], center: .center, startRadius: 2, endRadius: 34))
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.4), radius: 4, y: 4)
    }

    private var armShadow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).frame(width: 46, height: 30).offset(x: -58)
            Capsule().frame(width: length + 20, height: 7).offset(x: (length - 40) / 2)
            RoundedRectangle(cornerRadius: 3).frame(width: 40, height: 20).offset(x: length - 12)
        }
        .foregroundStyle(.black.opacity(0.32))
        .blur(radius: 4)
    }

    /// All offsets are measured from the pivot at the centre of the frame.
    private var arm: some View {
        let metal = LinearGradient(colors: [Color(white: 0.92), Color(white: 0.5), Color(white: 0.78)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            // Counterweight behind the pivot.
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 30)
                .offset(x: -58)
            // Tube.
            Capsule().fill(metal)
                .frame(width: length + 20, height: 7)
                .offset(x: (length - 40) / 2)
            // Bearing cap.
            Circle().fill(RadialGradient(colors: [Color(white: 0.9), Color(white: 0.35)], center: .topLeading, startRadius: 1, endRadius: 22))
                .frame(width: 30, height: 30)
            // Headshell and finger lift.
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.42)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.35), lineWidth: 1))
                .frame(width: 40, height: 20)
                .offset(x: length - 12)
            Capsule().fill(metal)
                .frame(width: 5, height: 26)
                .offset(x: length - 4, y: -18)
        }
    }
}
