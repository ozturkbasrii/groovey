import AppKit
import SwiftUI

/// A small floating list of recently played songs, opened by clicking the pile of records.
final class RecentsPanelController {
    private let history: HistoryStore
    private var panel: NSPanel?

    var isOpen: Bool { panel?.isVisible ?? false }

    init(history: HistoryStore) {
        self.history = history
    }

    /// Shows the panel centred horizontally on `anchor`, sitting just above it (screen coordinates).
    func show(above anchor: NSPoint) {
        let hosting = NSHostingView(rootView: RecentsList(history: history))
        let size = hosting.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = hosting
        panel.setFrameOrigin(NSPoint(x: anchor.x - size.width / 2, y: anchor.y + 14))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct RecentsList: View {
    @ObservedObject var history: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently Played")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(history.entries.prefix(6)) { entry in
                HStack(spacing: 10) {
                    SleeveFace(image: history.image(for: entry))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(verbatim: entry.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 12)
                    Text(entry.playedAt, style: .time)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
