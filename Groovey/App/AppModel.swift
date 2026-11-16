import AppKit
import Combine
import Sparkle

/// Owns the long-lived objects and wires them together.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let settings = Settings()
    let history = HistoryStore()
    let nowPlaying: NowPlayingService
    let power = PowerState()

    private(set) var desktop: DesktopWindowManager?
    private var updaterController: SPUStandardUpdaterController?

    /// Unit tests host the app; they must not open windows or spawn helpers.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private init() {
        nowPlaying = NowPlayingService(settings: settings, history: history)
    }

    @MainActor
    func start() {
        guard !Self.isRunningTests else { return }
        #if DEBUG
        if let directory = Snapshot.outputDirectory {
            Snapshot.renderAll(to: directory)
            NSApp.terminate(nil)
            return
        }
        #endif
        desktop = DesktopWindowManager(model: self)
        nowPlaying.start()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    func stop() {
        nowPlaying.stop()
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController?.checkForUpdates(nil)
    }

    func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "github.com/ozturkbasrii/groovey",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            )
        ])
    }
}

/// Tracks whether the displays are awake, so scenes can stop animating while they sleep.
final class PowerState: ObservableObject {
    @Published private(set) var displaysAwake = true
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.displaysAwake = false
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.displaysAwake = true
        })
    }

    deinit {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }
}
