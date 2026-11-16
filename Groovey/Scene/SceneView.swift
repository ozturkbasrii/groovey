import SwiftUI

/// Per-window state fed by AppKit.
final class WindowState: ObservableObject {
    /// False while other windows completely cover this desktop.
    @Published var isVisible = true
}

/// Root view of a desktop window.
struct SceneView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var nowPlaying: NowPlayingService
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var power: PowerState
    @ObservedObject var window: WindowState

    var body: some View {
        let theme = settings.theme
        let active = window.isVisible && power.displaysAwake
        let track = nowPlaying.track

        Group {
            if theme == .minimal {
                MinimalScene(
                    style: theme.style, track: track, artwork: nowPlaying.artwork,
                    palette: nowPlaying.palette, active: active, showInfo: settings.showTrackInfo
                )
            } else {
                RoomScene(
                    style: theme.style, track: track, artwork: nowPlaying.artwork,
                    palette: nowPlaying.palette,
                    pile: history.entries.filter { $0.id != track?.id },
                    image: history.image(for:),
                    active: active, showInfo: settings.showTrackInfo
                )
            }
        }
        .animation(.easeInOut(duration: 1.2), value: nowPlaying.palette)
        .animation(.easeInOut(duration: 0.6), value: theme)
        .ignoresSafeArea()
    }
}

/// Desk, wall and props: used by the Warm Room and Night themes.
struct RoomScene: View {
    let style: SceneStyle
    let track: Track?
    let artwork: NSImage?
    let palette: ArtworkPalette
    let pile: [HistoryEntry]
    let image: (HistoryEntry) -> NSImage?
    let active: Bool
    let showInfo: Bool

    private var brightness: Double { track?.isPlaying == true ? 1 : 0.45 }
    private var lampColor: Color { Color(hex: 0xFFB45E).blended(with: palette.accent, amount: 0.3) }

    var body: some View {
        GeometryReader { geometry in
            let scale = StageLayout.scale(for: geometry.size)
            let deskY = StageLayout.origin(for: geometry.size).y + StageLayout.deskLine * scale

            ZStack {
                Backdrop(style: style, accent: palette.accent, deskY: deskY, scale: scale)
                stage
                    .frame(width: StageLayout.size.width, height: StageLayout.size.height)
                    .scaleEffect(scale)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                Grain()
                Vignette(strength: style.vignette)
            }
            .animation(.easeInOut(duration: 1.0), value: brightness)
        }
    }

    private var stage: some View {
        ZStack {
            if style.hasLamp {
                Circle()
                    .fill(RadialGradient(
                        colors: [lampColor.opacity(0.62 * brightness), lampColor.opacity(0.2 * brightness), .clear],
                        center: .center, startRadius: 10, endRadius: 560
                    ))
                    .frame(width: 1120, height: 1120)
                    .blendMode(.screen)
                    .position(x: StageLayout.lamp.x, y: StageLayout.lamp.y - 110)
            }
            if style.hasLightBar {
                LightBar(color: palette.accent, brightness: brightness)
                    .position(x: StageLayout.turntable.x, y: 250)
            }

            if style.hasLamp {
                // Pool of light around the lamp's foot, and its long reflection in the polish.
                Ellipse()
                    .fill(lampColor.opacity(0.5 * brightness))
                    .frame(width: 560, height: 150)
                    .blur(radius: 46)
                    .blendMode(.screen)
                    .position(x: StageLayout.lamp.x, y: StageLayout.lamp.y + 168)
                Ellipse()
                    .fill(LinearGradient(colors: [lampColor.opacity(0.55 * brightness), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 300)
                    .blur(radius: 26)
                    .blendMode(.screen)
                    .position(x: StageLayout.lamp.x, y: StageLayout.lamp.y + 320)
            }
            if style.hasLightBar {
                Ellipse()
                    .fill(palette.accent.opacity(0.28 * brightness))
                    .frame(width: 620, height: 70)
                    .blur(radius: 40)
                    .blendMode(.screen)
                    .position(x: StageLayout.turntable.x, y: StageLayout.deskLine + 40)
            }

            CoverStand(style: style, artwork: artwork, artworkKey: (track?.id ?? "none") + (artwork == nil ? "0" : "1"))
                .position(StageLayout.coverStand)

            if style.hasLamp {
                Lamp(glow: lampColor, brightness: brightness)
                    .position(StageLayout.lamp)
            }

            TurntableView(style: style, track: track, artwork: artwork, accent: palette.accent, active: active)
                .position(StageLayout.turntable)

            RecentsPile(entries: pile, image: image)
                .position(x: StageLayout.pile.midX, y: StageLayout.pile.midY)

            if showInfo, let track {
                TrackCaption(track: track, color: style.text)
                    .frame(width: 360, alignment: .leading)
                    .position(x: 270, y: 735)
                    .transition(.opacity)
            }
        }
    }
}

/// Just the turntable from above, on a background tinted by the album.
struct MinimalScene: View {
    let style: SceneStyle
    let track: Track?
    let artwork: NSImage?
    let palette: ArtworkPalette
    let active: Bool
    let showInfo: Bool

    var body: some View {
        GeometryReader { geometry in
            let scale = StageLayout.scale(for: geometry.size)
            ZStack {
                LinearGradient(
                    colors: [palette.average.darkened(0.6), palette.average.darkened(0.86)],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [palette.accent.opacity(style.accentGlow), .clear],
                    center: .center, startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.5
                )
                .blendMode(.screen)

                ZStack {
                    TurntableTop(style: style, track: track, artwork: artwork, accent: palette.accent, active: active)
                        .shadow(color: .black.opacity(0.6), radius: 40, y: 30)
                        .scaleEffect(StageLayout.minimalScale)
                        .position(StageLayout.minimalTurntable)
                    if showInfo, let track {
                        TrackCaption(track: track, color: style.text, alignment: .center)
                            .frame(width: 700)
                            .position(x: 720, y: 745)
                            .transition(.opacity)
                    }
                }
                .frame(width: StageLayout.size.width, height: StageLayout.size.height)
                .scaleEffect(scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                Grain()
                Vignette(strength: style.vignette)
            }
        }
    }
}

/// Wall and desk, drawn edge to edge behind the stage.
private struct Backdrop: View {
    let style: SceneStyle
    let accent: Color
    let deskY: CGFloat
    let scale: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .top) {
                LinearGradient(colors: [style.wallTop, style.wallBottom], startPoint: .top, endPoint: .bottom)
                    .frame(height: deskY)
                RadialGradient(
                    colors: [accent.opacity(style.accentGlow), .clear],
                    center: UnitPoint(x: 0.5, y: 1), startRadius: 0, endRadius: size.width * 0.5
                )
                .frame(height: deskY)
                .blendMode(.screen)

                Group {
                    LinearGradient(colors: [style.deskBack, style.deskFront], startPoint: .top, endPoint: .bottom)
                    WoodBoards()
                    WoodGrain(lines: 260, seed: 0x9E37, strength: 1)
                    // Sheen: the lit wall reflects in the polished surface nearest to it.
                    LinearGradient(
                        stops: [
                            .init(color: style.wallBottom.opacity(0.42), location: 0),
                            .init(color: style.wallBottom.opacity(0.10), location: 0.22),
                            .init(color: .clear, location: 0.6),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .blendMode(.screen)
                    // Soft reflection of the room's light on the desk.
                    RadialGradient(
                        colors: [accent.opacity(style.accentGlow * 0.6), .clear],
                        center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: size.width * 0.45
                    )
                    .blendMode(.screen)
                    LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 44 * scale)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(height: max(0, size.height - deskY))
                .offset(y: deskY)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
    }
}

/// Fine lines running along the wood, tighter towards the back for a hint of depth.
struct WoodGrain: View {
    var lines: Int = 90
    var seed: UInt64 = 0x9E37
    var strength: Double = 1

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: seed)
            for index in 0..<lines {
                let depth = pow(Double(index) / Double(lines), 1.7)
                let y = depth * size.height
                let start = (random.next() - 0.25) * size.width
                let length = size.width * (0.25 + random.next() * 0.9)
                var path = Path()
                path.move(to: CGPoint(x: start, y: y))
                path.addCurve(
                    to: CGPoint(x: start + length, y: y + (random.next() - 0.5) * 5),
                    control1: CGPoint(x: start + length * 0.3, y: y + (random.next() - 0.5) * 9),
                    control2: CGPoint(x: start + length * 0.7, y: y + (random.next() - 0.5) * 9)
                )
                let light = random.next() > 0.55
                context.stroke(
                    path,
                    with: .color((light ? Color.white : Color.black).opacity((0.012 + random.next() * 0.04) * strength)),
                    lineWidth: 0.5 + depth * 1.8 * random.next()
                )
            }
        }
    }
}

/// Broad bands of slightly different tone, like boards cut from different parts of the tree.
private struct WoodBoards: View {
    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: 0xB0A2D5)
            var y: CGFloat = 0
            var index = 0
            while y < size.height {
                // Boards look deeper the closer they are to the viewer.
                let height = size.height * (0.035 + 0.05 * CGFloat(index)) * (0.8 + 0.4 * random.next())
                let tone = random.next() - 0.5
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: height)),
                    with: .color((tone > 0 ? Color.white : Color.black).opacity(abs(tone) * 0.09))
                )
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.12))
                )
                y += height
                index += 1
            }
        }
    }
}

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    /// A repeatable value in 0..<1, so textures do not shimmer between redraws.
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 33) / Double(1 << 31)
    }
}

/// Film-like grain over the whole scene. Flat gradients look computer-made; a little noise hides that.
struct Grain: View {
    private static let tile: CGImage? = {
        let side = 256
        var random = SeededRandom(seed: 0x6A41)
        var pixels = [UInt8](repeating: 0, count: side * side)
        for index in pixels.indices { pixels[index] = UInt8(random.next() * 255) }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }()

    var opacity: Double = 0.07

    var body: some View {
        if let tile = Self.tile {
            Image(decorative: tile, scale: 2)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

private struct Vignette: View {
    let strength: Double

    var body: some View {
        GeometryReader { geometry in
            let reach = max(geometry.size.width, geometry.size.height)
            RadialGradient(
                colors: [.clear, .black.opacity(strength)],
                center: .center, startRadius: reach * 0.32, endRadius: reach * 0.72
            )
        }
        .allowsHitTesting(false)
    }
}
