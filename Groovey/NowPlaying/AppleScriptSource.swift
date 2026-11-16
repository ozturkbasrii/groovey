import AppKit

/// Fallback for when the MediaRemote adapter stops working: asks Spotify and
/// Music directly over AppleScript. Needs the user's Automation permission.
final class AppleScriptSource {
    var onUpdate: ((Track?) -> Void)?

    private enum Player: CaseIterable {
        case spotify, music

        var bundleID: String {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            }
        }

        var infoScript: String {
            switch self {
            case .spotify:
                return """
                tell application id "com.spotify.client"
                    if player state is stopped then return {}
                    set t to current track
                    return {name of t, artist of t, album of t, (duration of t) / 1000, player position, (player state is playing), artwork url of t}
                end tell
                """
            case .music:
                return """
                tell application id "com.apple.Music"
                    if player state is stopped then return {}
                    set t to current track
                    return {name of t, artist of t, album of t, duration of t, player position, (player state is playing), ""}
                end tell
                """
            }
        }
    }

    // NSAppleScript is not thread safe; everything runs on this one serial queue.
    private let queue = DispatchQueue(label: "groovey.applescript")
    private var timer: DispatchSourceTimer?
    private var scripts: [String: NSAppleScript] = [:]
    private var artworkTrackID: String?
    private var artwork: Data?

    func start() {
        queue.async {
            guard self.timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 2)
            timer.setEventHandler { [weak self] in self?.poll() }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.async {
            self.timer?.cancel()
            self.timer = nil
        }
    }

    private func poll() {
        var found: Track?
        for player in Player.allCases where isRunning(player) {
            guard let track = read(player) else { continue }
            // Prefer whichever player is actually playing.
            if found == nil || (track.isPlaying && found?.isPlaying == false) { found = track }
        }
        DispatchQueue.main.async { self.onUpdate?(found) }
    }

    private func isRunning(_ player: Player) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).isEmpty
    }

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if let cached = scripts[source] {
            script = cached
        } else {
            guard let created = NSAppleScript(source: source) else { return nil }
            scripts[source] = created
            script = created
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    private func read(_ player: Player) -> Track? {
        guard let list = run(player.infoScript), list.numberOfItems >= 7,
              let title = list.atIndex(1)?.stringValue, !title.isEmpty else { return nil }

        var track = Track(
            title: title,
            artist: list.atIndex(2)?.stringValue ?? "",
            album: list.atIndex(3)?.stringValue ?? "",
            duration: list.atIndex(4)?.doubleValue,
            elapsed: list.atIndex(5)?.doubleValue,
            timestamp: Date(),
            isPlaying: list.atIndex(6)?.booleanValue ?? false,
            bundleID: player.bundleID
        )

        if artworkTrackID != track.id {
            artworkTrackID = track.id
            artwork = loadArtwork(player, url: list.atIndex(7)?.stringValue)
        }
        track.artwork = artwork
        return track
    }

    private func loadArtwork(_ player: Player, url: String?) -> Data? {
        switch player {
        case .spotify:
            guard let url, let remote = URL(string: url), remote.scheme == "https" else { return nil }
            return try? Data(contentsOf: remote)
        case .music:
            let script = """
            tell application id "com.apple.Music"
                try
                    return raw data of artwork 1 of current track
                end try
            end tell
            """
            guard let data = run(script)?.data, !data.isEmpty else { return nil }
            return data
        }
    }
}
