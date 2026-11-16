import SwiftUI

/// The turntable's top plate seen from straight above: platter, record, controls and tonearm.
struct TurntableTop: View {
    static let size = CGSize(width: 520, height: 420)
    static let recordDiameter: CGFloat = 358

    let style: SceneStyle
    let track: Track?
    let artwork: NSImage?
    let accent: Color
    /// False while the desktop is covered or the display sleeps; nothing animates then.
    let active: Bool

    private var isPlaying: Bool { track?.isPlaying ?? false }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [style.deckLight, style.deckDark], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1.5)

            // Platter rim.
            Circle()
                .fill(AngularGradient(
                    colors: [Color(white: 0.85), Color(white: 0.45), Color(white: 0.8), Color(white: 0.4), Color(white: 0.85)],
                    center: .center
                ))
                .frame(width: 376, height: 376)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 5)
                .position(TonearmGeometry.spindle)

            RecordView(artwork: artwork, accent: accent)
                .frame(width: Self.recordDiameter, height: Self.recordDiameter)
                .position(TonearmGeometry.spindle)
                .animation(.easeInOut(duration: 0.8), value: track?.id)

            // Speed knob and power light.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xE2C078), Color(hex: 0x8C6A2C)], center: .topLeading, startRadius: 1, endRadius: 26))
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 4)
                .position(x: 452, y: 356)
            Circle()
                .fill(isPlaying ? accent : Color(white: 0.2))
                .frame(width: 8, height: 8)
                .shadow(color: isPlaying ? accent : .clear, radius: 5)
                .position(x: 404, y: 358)
                .animation(.easeInOut(duration: 0.5), value: isPlaying)

            Group {
                if isPlaying && active {
                    // The arm creeps a fraction of a degree per tick; redrawing every two seconds is plenty.
                    TimelineView(.periodic(from: .now, by: 2)) { context in
                        tonearm(at: context.date)
                    }
                } else {
                    tonearm(at: Date())
                }
            }
            .position(TonearmGeometry.pivot)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

extension TurntableTop {
    /// Animates only the big moves (a new song, parking); the slow creep across the record just steps.
    private func tonearm(at date: Date) -> some View {
        TonearmView(angle: TonearmGeometry.angle(progress: track?.progress(at: date), hasTrack: track != nil))
            .animation(.easeInOut(duration: 1.1), value: track?.id)
    }
}

/// The turntable sitting on the desk, seen from above and in front.
struct TurntableView: View {
    /// Vertical foreshortening of the top plate.
    static let squash: CGFloat = 0.46
    static let frontHeight: CGFloat = 40

    let style: SceneStyle
    let track: Track?
    let artwork: NSImage?
    let accent: Color
    let active: Bool

    var body: some View {
        let width = TurntableTop.size.width
        let topHeight = TurntableTop.size.height * Self.squash

        ZStack(alignment: .top) {
            Ellipse()
                .fill(.black.opacity(0.55))
                .frame(width: width + 50, height: 64)
                .blur(radius: 20)
                .offset(y: topHeight + 4)

            // Front face, tucked up behind the plate's rounded corners.
            UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9)
                .fill(LinearGradient(colors: [style.woodLight, style.woodDark], startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: Self.frontHeight + 26)
                .offset(y: topHeight - 26)
            Text(verbatim: "GROOVEY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(5)
                .foregroundStyle(.black.opacity(0.4))
                .offset(y: topHeight + 14)

            TurntableTop(style: style, track: track, artwork: artwork, accent: accent, active: active)
                .scaleEffect(x: 1, y: Self.squash, anchor: .top)
                .frame(width: width, height: topHeight, alignment: .top)
        }
        .frame(width: width, height: topHeight + Self.frontHeight, alignment: .top)
    }
}
