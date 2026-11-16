import Foundation

/// Streams the system Now Playing session.
///
/// Since macOS 15.4 only Apple-signed processes may talk to MediaRemote, so the
/// work happens inside `/usr/bin/perl`, which loads the bundled adapter framework
/// and prints JSON lines. See Vendor/MediaRemoteAdapter.
final class MediaRemoteSource {
    /// Called on the main queue whenever the track changes (nil when nothing is playing).
    var onUpdate: ((Track?) -> Void)?
    /// Called on the main queue when the adapter keeps failing and a fallback is needed.
    var onFailure: (() -> Void)?

    private let queue = DispatchQueue(label: "groovey.mediaremote")
    private var process: Process?
    private var state = NowPlayingState()
    private var buffer = LineBuffer()
    private var consecutiveFailures = 0
    private var startedAt = Date()
    private var stopped = true

    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")

    private static var scriptURL: URL? {
        Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")
    }

    private static var frameworkURL: URL? {
        guard let url = Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static var isAvailable: Bool {
        scriptURL != nil && frameworkURL != nil && FileManager.default.isExecutableFile(atPath: perl.path)
    }

    func start() {
        queue.async {
            self.stopped = false
            self.consecutiveFailures = 0
            self.launch()
        }
    }

    func stop() {
        queue.async {
            self.stopped = true
            self.process?.terminate()
            self.process = nil
        }
    }

    /// Synchronous variant for app termination, so no helper process is left behind.
    func stopNow() {
        queue.sync {
            self.stopped = true
            self.process?.terminate()
            self.process = nil
        }
    }

    private func launch() {
        guard !stopped, let script = Self.scriptURL, let framework = Self.frameworkURL else {
            if !stopped { reportFailure() }
            return
        }

        Self.terminateStaleHelpers(script: script)

        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [script.path, framework.path, "stream", "--micros", "--debounce=80"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        state = NowPlayingState()
        buffer = LineBuffer()
        startedAt = Date()

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.queue.async { self?.consume(data) }
        }
        process.terminationHandler = { [weak self] finished in
            self?.queue.async { self?.handleExit(of: finished) }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            handleExit(of: process)
        }
    }

    /// A helper outlives the app if the app is killed outright; clear any left from a previous run.
    private static func terminateStaleHelpers(script: URL) {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-f", NSRegularExpression.escapedPattern(for: script.path) + ".* stream"]
        pkill.standardOutput = FileHandle.nullDevice
        pkill.standardError = FileHandle.nullDevice
        try? pkill.run()
        pkill.waitUntilExit()
    }

    private func consume(_ data: Data) {
        var changed = false
        for line in buffer.append(data) where state.apply(line: line) {
            changed = true
        }
        guard changed else { return }
        consecutiveFailures = 0
        let track = state.track
        DispatchQueue.main.async { self.onUpdate?(track) }
    }

    private func handleExit(of finished: Process) {
        guard !stopped, process === finished || process == nil else { return }
        process = nil
        // A stream that died right away never worked; one that ran for a while just needs a restart.
        if Date().timeIntervalSince(startedAt) < 5 { consecutiveFailures += 1 } else { consecutiveFailures = 0 }
        if consecutiveFailures >= 3 {
            reportFailure()
            return
        }
        queue.asyncAfter(deadline: .now() + 1.5) { self.launch() }
    }

    private func reportFailure() {
        stopped = true
        DispatchQueue.main.async {
            self.onUpdate?(nil)
            self.onFailure?()
        }
    }
}
