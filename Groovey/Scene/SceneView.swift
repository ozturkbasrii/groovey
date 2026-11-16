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
                    WoodGrain()
                    // Soft reflection of the room's light on the desk.
                    RadialGradient(
                        colors: [accent.opacity(style.accentGlow * 0.6), .clear],
                        center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: size.width * 0.45
                    )
                    .blendMode(.screen)
                    LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 30 * scale)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(height: max(0, size.height - deskY))
                .offset(y: deskY)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
    }
}

/// Faint lines running along the desk, tighter towards the back for a hint of depth.
private struct WoodGrain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func random() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 33) / Double(1 << 31)
            }
            for index in 0..<90 {
                let depth = pow(Double(index) / 90, 1.7)
                let y = depth * size.height
                let start = random() * size.width * 0.5
                let length = size.width * (0.3 + random() * 0.7)
                var path = Path()
                path.move(to: CGPoint(x: start, y: y))
                path.addQuadCurve(
                    to: CGPoint(x: start + length, y: y + (random() - 0.5) * 6),
                    control: CGPoint(x: start + length / 2, y: y + (random() - 0.5) * 10)
                )
                let light = random() > 0.5
                context.stroke(
                    path,
                    with: .color((light ? Color.white : Color.black).opacity(0.015 + random() * 0.035)),
                    lineWidth: 0.6 + depth * 1.6
                )
            }
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
