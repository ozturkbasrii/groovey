#if DEBUG
import AppKit
import SwiftUI

/// Renders every scene to PNG files with made-up songs, for the README and for checking the drawing code.
/// Run a debug build with `GROOVEY_SNAPSHOT=/some/folder` set.
enum Snapshot {
    static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["GROOVEY_SNAPSHOT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    @MainActor
    static func renderAll(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let covers = (0..<5).map(demoCover)
        let pile = (1..<5).map { index in
            HistoryEntry(id: "demo-\(index)", title: "Song \(index)", artist: "Artist", album: "", bundleID: "", playedAt: Date(), artworkFile: nil)
        }
        let artwork = covers[0]
        let palette = ArtworkPalette(image: artwork) ?? .neutral
        let track = Track(
            title: "Midnight on Wax", artist: "The Groove Assembly", album: "Side A",
            duration: 240, elapsed: 96, timestamp: Date(), isPlaying: true, bundleID: "demo"
        )

        for theme in Theme.allCases {
            for (suffix, current) in [("", Optional(track)), ("-idle", nil)] {
                let scene = Group {
                    if theme == .minimal {
                        MinimalScene(
                            style: theme.style, track: current, artwork: current == nil ? nil : artwork,
                            palette: current == nil ? .neutral : palette, active: false, showInfo: true
                        )
                    } else {
                        RoomScene(
                            style: theme.style, track: current, artwork: current == nil ? nil : artwork,
                            palette: current == nil ? .neutral : palette,
                            pile: current == nil ? [] : pile,
                            image: { entry in covers[(Int(entry.id.suffix(1)) ?? 0) % covers.count] },
                            active: false, showInfo: true
                        )
                    }
                }
                .frame(width: 1440, height: 900)

                let renderer = ImageRenderer(content: scene)
                renderer.scale = 2
                guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
                try? png.write(to: directory.appendingPathComponent("\(theme.rawValue)\(suffix).png"))
            }
        }
    }

    /// Writes what a live desktop window is showing to `GROOVEY_DUMP` a few seconds after launch.
    static func dumpLiveWindowIfRequested(_ window: NSWindow) {
        guard let path = ProcessInfo.processInfo.environment["GROOVEY_DUMP"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds),
                  let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
            // Render the layer tree so the Core Animation label overlay is included.
            view.layer?.render(in: context.cgContext)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            let info = "level=\(window.level.rawValue) frame=\(window.frame) visible=\(window.isVisible) occluded=\(!window.occlusionState.contains(.visible))\n"
            try? info.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
        }
    }

    /// A simple abstract cover, different for each index.
    private static func demoCover(_ index: Int) -> NSImage {
        let palettes: [[NSColor]] = [
            [NSColor(red: 0.10, green: 0.16, blue: 0.36, alpha: 1), NSColor(red: 0.95, green: 0.42, blue: 0.28, alpha: 1), NSColor(red: 0.98, green: 0.82, blue: 0.52, alpha: 1)],
            [NSColor(red: 0.07, green: 0.30, blue: 0.28, alpha: 1), NSColor(red: 0.93, green: 0.80, blue: 0.40, alpha: 1), NSColor(red: 0.96, green: 0.94, blue: 0.86, alpha: 1)],
            [NSColor(red: 0.42, green: 0.10, blue: 0.22, alpha: 1), NSColor(red: 0.96, green: 0.60, blue: 0.66, alpha: 1), NSColor(red: 0.99, green: 0.90, blue: 0.84, alpha: 1)],
            [NSColor(red: 0.90, green: 0.88, blue: 0.80, alpha: 1), NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1), NSColor(red: 0.84, green: 0.30, blue: 0.20, alpha: 1)],
            [NSColor(red: 0.20, green: 0.14, blue: 0.40, alpha: 1), NSColor(red: 0.38, green: 0.78, blue: 0.86, alpha: 1), NSColor(red: 0.94, green: 0.94, blue: 0.98, alpha: 1)],
        ]
        let colors = palettes[index % palettes.count]
        return NSImage(size: NSSize(width: 600, height: 600), flipped: false) { rect in
            colors[0].setFill()
            rect.fill()
            colors[1].setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 90, dy: 90).offsetBy(dx: CGFloat(index * 20) - 30, dy: -40)).fill()
            colors[2].setFill()
            NSBezierPath(ovalIn: NSRect(x: 330 - CGFloat(index * 30), y: 330, width: 170, height: 170)).fill()
            return true
        }
    }
}
#endif
