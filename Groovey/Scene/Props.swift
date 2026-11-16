import SwiftUI

/// The front of a record sleeve: the cover art, or a plain paper sleeve when there is none.
struct SleeveFace: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(hex: 0xD9CDB8), Color(hex: 0xB8A98E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color(white: 0.08)).padding(.all, 46)
                Circle().fill(Color(hex: 0xC9703A)).padding(.all, 108)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        )
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.3), lineWidth: 1))
    }
}

/// The current album propped upright in a wooden stand.
struct CoverStand: View {
    static let sleeveSide: CGFloat = 290

    let style: SceneStyle
    let artwork: NSImage?
    /// Changes whenever the displayed cover should cross-fade.
    let artworkKey: String

    var body: some View {
        VStack(spacing: -10) {
            ZStack {
                SleeveFace(image: artwork)
                    .id(artworkKey)
                    .transition(.opacity)
            }
            .frame(width: Self.sleeveSide, height: Self.sleeveSide)
            .animation(.easeInOut(duration: 0.9), value: artworkKey)
            .rotation3DEffect(.degrees(-9), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .rotation3DEffect(.degrees(6), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.3)
            .shadow(color: .black.opacity(0.5), radius: 18, x: 14, y: 10)
            .zIndex(1)

            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [style.woodLight, style.woodDark], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .frame(width: Self.sleeveSide + 44, height: 26)
            .shadow(color: .black.opacity(0.55), radius: 10, y: 8)
            .zIndex(2)
        }
    }
}

/// Earlier records lying in a loose pile on the desk.
struct RecentsPile: View {
    let entries: [HistoryEntry]
    let image: (HistoryEntry) -> NSImage?

    private static let angles: [Double] = [-9, 13, -4, 19, 4]
    private static let offsets: [CGSize] = [
        .init(width: 0, height: 0), .init(width: 16, height: -8), .init(width: -14, height: 6),
        .init(width: 10, height: 12), .init(width: -6, height: -10),
    ]

    var body: some View {
        let shown = Array(entries.prefix(5).enumerated())
        ZStack {
            // Newest first in `entries`, so draw in reverse to leave it on top.
            ForEach(shown.reversed(), id: \.element.id) { index, entry in
                SleeveFace(image: image(entry))
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(Self.angles[index % 5]))
                    .offset(Self.offsets[index % 5])
                    .scaleEffect(x: 1, y: TurntableView.squash)
                    .offset(y: -CGFloat(shown.count - 1 - index) * 5)
                    .shadow(color: .black.opacity(0.5), radius: 7, y: 6)
            }
        }
        .frame(width: StageLayout.pile.width, height: StageLayout.pile.height)
        .animation(.easeInOut(duration: 0.6), value: entries.first?.id)
    }
}

/// A dome lamp. `brightness` runs from 0 (off) to 1.
struct Lamp: View {
    static let size = CGSize(width: 220, height: 330)

    let glow: Color
    let brightness: Double

    var body: some View {
        let brass = LinearGradient(colors: [Color(hex: 0xD9B46A), Color(hex: 0x7A5A22)], startPoint: .leading, endPoint: .trailing)
        ZStack(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.5)).frame(width: 170, height: 30).blur(radius: 10).offset(y: 10)
            Ellipse().fill(brass).frame(width: 128, height: 30)
            Rectangle().fill(brass).frame(width: 12, height: 190).offset(y: -16)
            DomeShape()
                .fill(LinearGradient(
                    colors: [
                        Color(hex: 0x7A5238).blended(with: Color(hex: 0xFFF1D0), amount: brightness),
                        Color(hex: 0x4A2E1E).blended(with: glow, amount: brightness * 0.85),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(DomeShape().stroke(.black.opacity(0.18), lineWidth: 1))
                .frame(width: 210, height: 150)
                .shadow(color: glow.opacity(0.7 * brightness), radius: 30)
                .offset(y: -180)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .bottom)
    }
}

/// A half ellipse with a flat bottom edge.
private struct DomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.62),
            control2: CGPoint(x: rect.midX - rect.width * 0.3, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.midX + rect.width * 0.3, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.62)
        )
        path.closeSubpath()
        return path
    }
}

/// A slim light on the wall for the Night scene, coloured by the album.
struct LightBar: View {
    let color: Color
    let brightness: Double

    var body: some View {
        ZStack {
            Capsule().fill(color.opacity(0.55 * brightness)).frame(width: 560, height: 60).blur(radius: 50)
            Capsule().fill(color.opacity(0.9 * brightness)).frame(width: 460, height: 12).blur(radius: 8)
            Capsule().fill(Color.white.blended(with: color, amount: 0.25).opacity(0.35 + 0.65 * brightness)).frame(width: 440, height: 5)
        }
    }
}

struct TrackCaption: View {
    let track: Track
    let color: Color
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(verbatim: track.title)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .lineLimit(2)
            if !track.artist.isEmpty {
                Text(verbatim: track.artist)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .opacity(0.72)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .foregroundStyle(color)
        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
    }
}
