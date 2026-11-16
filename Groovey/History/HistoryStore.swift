import AppKit

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var bundleID: String
    var playedAt: Date
    /// File name of the saved cover inside the store's directory.
    var artworkFile: String?
}

/// The most recently played songs, newest first, kept on disk.
final class HistoryStore: ObservableObject {
    static let capacity = 20

    @Published private(set) var entries: [HistoryEntry] = []

    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("history.json") }
    private var imageCache: [String: NSImage] = [:]

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Groovey", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        load()
    }

    /// Adds the track, or moves it to the front if it is already known.
    func record(_ track: Track) {
        if let first = entries.first, first.id == track.id {
            // Covers often arrive a moment after the title does.
            if first.artworkFile == nil, let artwork = track.artwork {
                entries[0].artworkFile = saveArtwork(artwork, for: track.id)
                save()
            }
            return
        }

        var entry = entries.first { $0.id == track.id } ?? HistoryEntry(
            id: track.id, title: track.title, artist: track.artist, album: track.album,
            bundleID: track.bundleID, playedAt: Date(), artworkFile: nil
        )
        entry.playedAt = Date()
        if entry.artworkFile == nil, let artwork = track.artwork {
            entry.artworkFile = saveArtwork(artwork, for: track.id)
        }

        var updated = entries.filter { $0.id != track.id }
        updated.insert(entry, at: 0)
        for removed in updated.dropFirst(Self.capacity) { deleteArtwork(of: removed) }
        entries = Array(updated.prefix(Self.capacity))
        save()
    }

    func clear() {
        entries.forEach(deleteArtwork)
        entries = []
        save()
    }

    func image(for entry: HistoryEntry) -> NSImage? {
        guard let file = entry.artworkFile else { return nil }
        if let cached = imageCache[file] { return cached }
        let image = NSImage(contentsOf: directory.appendingPathComponent(file))
        imageCache[file] = image
        return image
    }

    // MARK: Disk

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func saveArtwork(_ data: Data, for id: String) -> String? {
        guard let image = NSImage(data: data), let jpeg = Self.thumbnail(of: image, side: 360) else { return nil }
        let name = Self.fileName(for: id)
        do {
            try jpeg.write(to: directory.appendingPathComponent(name), options: .atomic)
            imageCache[name] = nil
            return name
        } catch {
            return nil
        }
    }

    private func deleteArtwork(of entry: HistoryEntry) {
        guard let file = entry.artworkFile else { return }
        imageCache[file] = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
    }

    /// Stable, filesystem-safe name derived from the track id (FNV-1a).
    static func fileName(for id: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "cover-%016llx.jpg", hash)
    }

    private static func thumbnail(of image: NSImage, side: Int) -> Data? {
        guard
            let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let scaled = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled).representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}
