import Foundation

/// A snapshot of what the system (or a player app) reports as playing.
struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    /// Seconds. Nil for live streams and sources that do not report it.
    var duration: TimeInterval?
    /// Playback position, in seconds, measured at `timestamp`.
    var elapsed: TimeInterval?
    var timestamp: Date?
    var isPlaying: Bool
    var playbackRate: Double = 1
    var bundleID: String
    var artwork: Data?

    /// Identifies the song, ignoring position, play state and artwork.
    var id: String { "\(bundleID)\u{1F}\(title)\u{1F}\(artist)\u{1F}\(album)" }

    /// Estimated playback position at `date`.
    func elapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        var value = elapsed
        if isPlaying, let timestamp {
            value += date.timeIntervalSince(timestamp) * playbackRate
        }
        if let duration, duration > 0 { value = min(value, duration) }
        return max(0, value)
    }

    /// 0 at the start of the song, 1 at the end. Nil when unknown.
    func progress(at date: Date) -> Double? {
        guard let duration, duration > 0, let position = elapsed(at: date) else { return nil }
        return min(1, max(0, position / duration))
    }
}

/// Folds the adapter's JSON lines (full payloads and diffs) into the current track.
struct NowPlayingState {
    private(set) var values: [String: Any] = [:]

    /// Applies one line of `mediaremote-adapter.pl stream --micros` output.
    /// Returns false when the line is not a data message.
    @discardableResult
    mutating func apply(line: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            object["type"] as? String == "data",
            let payload = object["payload"] as? [String: Any]
        else { return false }

        if object["diff"] as? Bool == true {
            for (key, value) in payload {
                if value is NSNull { values[key] = nil } else { values[key] = value }
            }
        } else {
            values = payload.filter { !($0.value is NSNull) }
        }
        return true
    }

    var track: Track? {
        guard let title = values["title"] as? String, !title.isEmpty else { return nil }
        let bundle = (values["parentApplicationBundleIdentifier"] as? String)
            ?? (values["bundleIdentifier"] as? String) ?? ""
        return Track(
            title: title,
            artist: values["artist"] as? String ?? "",
            album: values["album"] as? String ?? "",
            duration: Self.seconds(values["durationMicros"]),
            elapsed: Self.seconds(values["elapsedTimeMicros"]),
            timestamp: Self.seconds(values["timestampEpochMicros"]).map(Date.init(timeIntervalSince1970:)),
            isPlaying: values["playing"] as? Bool ?? false,
            playbackRate: (values["playbackRate"] as? NSNumber)?.doubleValue ?? 1,
            bundleID: bundle,
            artwork: (values["artworkData"] as? String).flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        )
    }

    private static func seconds(_ micros: Any?) -> TimeInterval? {
        guard let number = micros as? NSNumber else { return nil }
        return number.doubleValue / 1_000_000
    }
}

/// Splits a byte stream into newline-terminated chunks.
struct LineBuffer {
    private var pending = Data()

    mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var lines: [Data] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = pending[pending.startIndex..<newline]
            if !line.isEmpty { lines.append(Data(line)) }
            pending.removeSubrange(pending.startIndex...newline)
        }
        return lines
    }
}
