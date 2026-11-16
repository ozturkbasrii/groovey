import AppKit
import Combine

/// Publishes the current track for the UI, choosing between the system feed and the AppleScript fallback.
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var palette: ArtworkPalette = .neutral
    /// True once the app had to fall back to asking players directly.
    @Published private(set) var usingFallback = false

    private let settings: Settings
    private let history: HistoryStore
    private let mediaRemote = MediaRemoteSource()
    private let appleScript = AppleScriptSource()
    private var rawTrack: Track?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: Settings, history: HistoryStore) {
        self.settings = settings
        self.history = history

        mediaRemote.onUpdate = { [weak self] in self?.receive($0) }
        mediaRemote.onFailure = { [weak self] in self?.startFallback() }
        appleScript.onUpdate = { [weak self] in self?.receive($0) }

        settings.$source
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.publish() }
            }
            .store(in: &cancellables)
    }

    func start() {
        if MediaRemoteSource.isAvailable, ProcessInfo.processInfo.environment["GROOVEY_FORCE_APPLESCRIPT"] == nil {
            mediaRemote.start()
        } else {
            startFallback()
        }
    }

    func stop() {
        mediaRemote.stopNow()
        appleScript.stop()
    }

    private func startFallback() {
        usingFallback = true
        appleScript.start()
    }

    private func receive(_ track: Track?) {
        rawTrack = track
        publish()
    }

    private func publish() {
        var next = rawTrack
        if let candidate = next, !settings.source.accepts(bundleID: candidate.bundleID) { next = nil }

        let previous = track
        guard next != previous else { return }
        track = next

        if next?.artwork != previous?.artwork || next?.id != previous?.id {
            let image = next?.artwork.flatMap(NSImage.init(data:))
            artwork = image
            palette = image.flatMap(ArtworkPalette.init(image:)) ?? .neutral
        }

        if let next, next.isPlaying {
            history.record(next)
        }
    }
}
