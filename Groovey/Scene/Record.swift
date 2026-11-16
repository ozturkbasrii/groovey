import SwiftUI

/// A vinyl record seen from straight above. It is drawn still: the grooves are
/// rotationally symmetric, and the turning label is laid over it by `SpinningLabelView`.
struct RecordView: View {
    /// Label diameter as a fraction of the record's.
    static let labelRatio: CGFloat = 0.36

    let artwork: NSImage?
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(
                    RadialGradient(
                        colors: [Color(white: 0.12), Color(white: 0.035)],
                        center: .center, startRadius: diameter * 0.18, endRadius: diameter * 0.5
                    )
                )
                Grooves()
                Circle()
                    .fill(AngularGradient(stops: Self.sheen, center: .center))
                    .mask(Circle().strokeBorder(lineWidth: diameter * 0.29))
                    .rotationEffect(.degrees(-38))
                    .blendMode(.screen)

                RecordLabel(artwork: artwork, accent: accent)
                    .frame(width: diameter * Self.labelRatio, height: diameter * Self.labelRatio)
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: diameter * 0.03, height: diameter * 0.03)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private static let sheen: [Gradient.Stop] = [
        .init(color: .clear, location: 0),
        .init(color: .white.opacity(0.20), location: 0.07),
        .init(color: .clear, location: 0.15),
        .init(color: .clear, location: 0.5),
        .init(color: .white.opacity(0.13), location: 0.57),
        .init(color: .clear, location: 0.65),
        .init(color: .clear, location: 1),
    ]

}

/// The paper label at the centre of the record: the album art, or a plain one in the accent colour.
struct RecordLabel: View {
    let artwork: NSImage?
    let accent: Color

    /// The label as a bitmap, for the Core Animation layer that spins it.
    @MainActor
    static func image(artwork: NSImage?, accent: Color) -> CGImage? {
        let renderer = ImageRenderer(content: RecordLabel(artwork: artwork, accent: accent).frame(width: 240, height: 240))
        renderer.scale = 2
        return renderer.cgImage
    }

    var body: some View {
        ZStack {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                ZStack {
                    accent.darkened(0.15)
                    Circle().strokeBorder(.black.opacity(0.25), lineWidth: 2).padding(10)
                    Rectangle().fill(.black.opacity(0.3)).frame(height: 2).offset(y: -16)
                }
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1.5))
    }
}

/// The fine concentric lines of a record, with a few wider gaps between "tracks".
private struct Grooves: View {
    var body: some View {
        Canvas { context, size in
            let diameter = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var radius = diameter * 0.212
            var index = 0
            while radius < diameter * 0.486 {
                // Cheap deterministic noise so the lines vary without flickering between redraws.
                let noise = Double((index &* 2_654_435_761) % 97) / 97
                let isGap = index % 23 == 22
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(isGap ? .black.opacity(0.7) : .white.opacity(0.025 + noise * 0.05)),
                    lineWidth: isGap ? diameter * 0.006 : diameter * 0.0018
                )
                radius += diameter * 0.0052
                index += 1
            }
        }
    }
}
