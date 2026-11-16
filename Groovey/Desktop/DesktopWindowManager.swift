import AppKit
import Combine
import SwiftUI

/// A borderless window that sits above the wallpaper and below the desktop icons.
final class DesktopWindow: NSWindow {
    let state = WindowState()
    var labelOverlay: LabelOverlay?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        setFrame(screen.frame, display: true)
    }
}

/// Keeps one scene window on every display and decides when they are shown.
final class DesktopWindowManager {
    private unowned let model: AppModel
    private var windows: [DesktopWindow] = []
    private var shouldShow = true
    private var cancellables: Set<AnyCancellable> = []
    private var observers: [NSObjectProtocol] = []
    private var clickMonitor: Any?
    private let recents: RecentsPanelController

    init(model: AppModel) {
        self.model = model
        recents = RecentsPanelController(history: model.history)

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.rebuild()
        })
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? DesktopWindow else { return }
            window.state.isVisible = window.occlusionState.contains(.visible)
        })

        Publishers.CombineLatest3(
            model.settings.$showOnDesktop,
            model.settings.$hideWhenPaused,
            model.nowPlaying.$track.map { $0?.isPlaying ?? false }.removeDuplicates()
        )
        .map { show, hideWhenPaused, playing in show && (playing || !hideWhenPaused) }
        .removeDuplicates()
        // Skipping between songs briefly reports "paused"; do not flicker the desktop for that.
        .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
        .sink { [weak self] show in self?.setShown(show) }
        .store(in: &cancellables)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.handleClick(at: NSEvent.mouseLocation)
        }

        shouldShow = model.settings.showOnDesktop
        rebuild()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    }

    private func rebuild() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { screen in
            let created = DesktopWindow(screen: screen)
            let hosting = NSHostingView(
                rootView: SceneView(window: created.state)
                    .environmentObject(model.settings)
                    .environmentObject(model.nowPlaying)
                    .environmentObject(model.history)
                    .environmentObject(model.power)
            )
            let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            container.wantsLayer = true
            hosting.frame = container.bounds
            hosting.autoresizingMask = [.width, .height]
            container.addSubview(hosting)
            created.contentView = container
            created.labelOverlay = LabelOverlay(model: model, state: created.state, container: container)
            if shouldShow { created.orderFrontRegardless() }
            #if DEBUG
            Snapshot.dumpLiveWindowIfRequested(created)
            #endif
            return created
        }
    }

    private func setShown(_ show: Bool) {
        shouldShow = show
        if !show { recents.close() }
        for window in windows {
            if show {
                window.alphaValue = 0
                window.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.7
                    window.animator().alphaValue = 1
                }
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.7
                    window.animator().alphaValue = 0
                }, completionHandler: { [weak self, weak window] in
                    if self?.shouldShow == false { window?.orderOut(nil) }
                })
            }
        }
    }

    // MARK: Clicking the pile of records

    /// The scene sits below the desktop icons and never receives clicks itself,
    /// so clicks are watched globally and matched against the pile's position.
    private func handleClick(at point: NSPoint) {
        if recents.isOpen {
            recents.close()
            return
        }
        guard shouldShow, model.settings.theme != .minimal,
              model.history.entries.contains(where: { $0.id != model.nowPlaying.track?.id }),
              let window = windows.first(where: { $0.frame.contains(point) }) else { return }

        let pile = StageLayout.rect(StageLayout.pile, in: window.frame.size)
        let local = CGPoint(x: point.x - window.frame.minX, y: window.frame.maxY - point.y)
        guard pile.contains(local), Self.isDesktopExposed(at: point) else { return }

        let anchor = NSPoint(x: window.frame.minX + pile.midX, y: window.frame.maxY - pile.minY)
        recents.show(above: anchor)
    }

    /// True when no ordinary window covers `point` (screen coordinates, origin bottom-left).
    static func isDesktopExposed(at point: NSPoint) -> Bool {
        guard let primary = NSScreen.screens.first,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return true }

        let flipped = CGPoint(x: point.x, y: primary.frame.height - point.y)
        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        for info in list {
            // Layer 0 holds normal windows; small positive layers are floating panels. The Dock and menu bar sit higher.
            guard let layer = info[kCGWindowLayer as String] as? Int, (0..<20).contains(layer),
                  (info[kCGWindowOwnerPID as String] as? Int) != ownPID,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary)
            else { continue }
            if bounds.contains(flipped) { return false }
        }
        return true
    }
}
