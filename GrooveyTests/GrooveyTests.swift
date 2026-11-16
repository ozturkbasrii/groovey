import XCTest
@testable import Groovey

final class NowPlayingStateTests: XCTestCase {
    private func line(_ json: String) -> Data { Data(json.utf8) }

    func testFullPayloadBecomesTrack() {
        var state = NowPlayingState()
        let applied = state.apply(line: line("""
        {"type":"data","diff":false,"payload":{"title":"Song","artist":"Band","album":"LP","playing":true,\
        "bundleIdentifier":"com.spotify.client","durationMicros":200000000,"elapsedTimeMicros":50000000,\
        "timestampEpochMicros":1700000000000000,"playbackRate":1}}
        """))
        XCTAssertTrue(applied)

        let track = try? XCTUnwrap(state.track)
        XCTAssertEqual(track?.title, "Song")
        XCTAssertEqual(track?.artist, "Band")
        XCTAssertEqual(track?.duration, 200)
        XCTAssertEqual(track?.elapsed, 50)
        XCTAssertEqual(track?.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(track?.isPlaying, true)
        XCTAssertEqual(track?.bundleID, "com.spotify.client")
    }

    func testDiffMergesAndNullRemoves() {
        var state = NowPlayingState()
        state.apply(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","artist":"X","playing":true,"bundleIdentifier":"b"}}"#))
        state.apply(line: line(#"{"type":"data","diff":true,"payload":{"playing":false,"artist":null}}"#))

        XCTAssertEqual(state.track?.title, "A")
        XCTAssertEqual(state.track?.artist, "")
        XCTAssertEqual(state.track?.isPlaying, false)
    }

    func testEmptyPayloadMeansNothingPlaying() {
        var state = NowPlayingState()
        state.apply(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","playing":true,"bundleIdentifier":"b"}}"#))
        state.apply(line: line(#"{"type":"data","diff":false,"payload":{}}"#))
        XCTAssertNil(state.track)
    }

    func testGarbageIsIgnored() {
        var state = NowPlayingState()
        XCTAssertFalse(state.apply(line: line("not json")))
        XCTAssertFalse(state.apply(line: line(#"{"type":"other"}"#)))
        XCTAssertNil(state.track)
    }

    func testBrowserTabsReportTheParentApp() {
        var state = NowPlayingState()
        state.apply(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","playing":true,"bundleIdentifier":"com.apple.WebKit.GPU","parentApplicationBundleIdentifier":"com.apple.Safari"}}"#))
        XCTAssertEqual(state.track?.bundleID, "com.apple.Safari")
    }

    func testArtworkIsDecodedFromBase64() {
        var state = NowPlayingState()
        let encoded = Data([1, 2, 3, 4]).base64EncodedString()
        state.apply(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","playing":true,"bundleIdentifier":"b","artworkData":"\#(encoded)"}}"#))
        XCTAssertEqual(state.track?.artwork, Data([1, 2, 3, 4]))
    }
}

final class LineBufferTests: XCTestCase {
    func testSplitsAcrossChunks() {
        var buffer = LineBuffer()
        XCTAssertEqual(buffer.append(Data("ab".utf8)), [])
        XCTAssertEqual(buffer.append(Data("c\nde\n\nf".utf8)), [Data("abc".utf8), Data("de".utf8)])
        XCTAssertEqual(buffer.append(Data("\n".utf8)), [Data("f".utf8)])
    }
}

final class TrackTests: XCTestCase {
    private func track(elapsed: TimeInterval?, duration: TimeInterval?, playing: Bool, at timestamp: Date) -> Track {
        Track(title: "T", artist: "", album: "", duration: duration, elapsed: elapsed, timestamp: timestamp, isPlaying: playing, bundleID: "b")
    }

    func testElapsedAdvancesOnlyWhilePlaying() {
        let start = Date(timeIntervalSince1970: 1000)
        let later = start.addingTimeInterval(10)
        XCTAssertEqual(track(elapsed: 30, duration: 100, playing: true, at: start).elapsed(at: later), 40)
        XCTAssertEqual(track(elapsed: 30, duration: 100, playing: false, at: start).elapsed(at: later), 30)
    }

    func testProgressIsClampedAndOptional() {
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(track(elapsed: 95, duration: 100, playing: true, at: start).progress(at: start.addingTimeInterval(60)), 1)
        XCTAssertEqual(track(elapsed: 25, duration: 100, playing: false, at: start).progress(at: start), 0.25)
        XCTAssertNil(track(elapsed: 25, duration: nil, playing: true, at: start).progress(at: start))
        XCTAssertNil(track(elapsed: nil, duration: 100, playing: true, at: start).progress(at: start))
    }

    func testIdentityIgnoresPositionAndArtwork() {
        let start = Date()
        var a = track(elapsed: 1, duration: 100, playing: true, at: start)
        let b = track(elapsed: 50, duration: 100, playing: false, at: start)
        a.artwork = Data([1])
        XCTAssertEqual(a.id, b.id)
    }
}

final class TonearmTests: XCTestCase {
    private func stylusRadius(atAngle angle: Double) -> CGFloat {
        let stylus = TonearmGeometry.stylus(atAngle: angle)
        return hypot(stylus.x - TonearmGeometry.spindle.x, stylus.y - TonearmGeometry.spindle.y)
    }

    func testStylusTracksFromOuterToInnerGroove() {
        XCTAssertEqual(stylusRadius(atAngle: TonearmGeometry.angle(progress: 0, hasTrack: true)), TonearmGeometry.outerGroove, accuracy: 0.01)
        XCTAssertEqual(stylusRadius(atAngle: TonearmGeometry.angle(progress: 1, hasTrack: true)), TonearmGeometry.innerGroove, accuracy: 0.01)
        XCTAssertEqual(stylusRadius(atAngle: TonearmGeometry.angle(progress: 0.5, hasTrack: true)), 125, accuracy: 0.01)
    }

    func testArmParksOffTheRecordWithoutATrack() {
        let radius = stylusRadius(atAngle: TonearmGeometry.angle(progress: 0.5, hasTrack: false))
        XCTAssertEqual(radius, TonearmGeometry.restRadius, accuracy: 0.01)
        XCTAssertGreaterThan(radius, 179, "the parked stylus must clear the record's edge")
    }

    func testParkedStylusStaysOnThePlate() {
        let stylus = TonearmGeometry.stylus(atAngle: TonearmGeometry.angle(progress: nil, hasTrack: false))
        XCTAssertTrue(CGRect(origin: .zero, size: TurntableTop.size).insetBy(dx: 20, dy: 20).contains(stylus))
    }

    func testOutOfRangeProgressIsClamped() {
        XCTAssertEqual(TonearmGeometry.angle(progress: 7, hasTrack: true), TonearmGeometry.angle(progress: 1, hasTrack: true))
        XCTAssertEqual(TonearmGeometry.angle(progress: nil, hasTrack: true), TonearmGeometry.angle(progress: 0, hasTrack: true))
    }
}

final class StageLayoutTests: XCTestCase {
    func testStageIsCentredAndFitted() {
        // Twice the stage size: everything simply doubles.
        XCTAssertEqual(StageLayout.rect(CGRect(x: 10, y: 20, width: 30, height: 40), in: CGSize(width: 2880, height: 1800)),
                       CGRect(x: 20, y: 40, width: 60, height: 80))
        // A wider display letterboxes horizontally.
        let wide = StageLayout.rect(CGRect(x: 0, y: 0, width: 1440, height: 900), in: CGSize(width: 2000, height: 900))
        XCTAssertEqual(wide, CGRect(x: 280, y: 0, width: 1440, height: 900))
    }
}

final class LabelPlacementTests: XCTestCase {
    func testLabelSitsOnTheSpindle() {
        let stage = StageLayout.size
        let room = StageLayout.label(theme: .warmRoom, in: stage)
        XCTAssertEqual(room.center.x, 602, accuracy: 0.01)
        XCTAssertEqual(room.center.y, 608, accuracy: 0.01)
        XCTAssertEqual(room.squash, TurntableView.squash)

        let minimal = StageLayout.label(theme: .minimal, in: stage)
        XCTAssertEqual(minimal.center.x, 670.6, accuracy: 0.01)
        XCTAssertEqual(minimal.center.y, 405, accuracy: 0.01)
        XCTAssertEqual(minimal.squash, 1)
        XCTAssertEqual(minimal.diameter, room.diameter * 1.3, accuracy: 0.01)
    }

    func testLabelScalesWithTheDisplay() {
        let doubled = StageLayout.label(theme: .night, in: CGSize(width: 2880, height: 1800))
        XCTAssertEqual(doubled.center.x, 1204, accuracy: 0.01)
        XCTAssertEqual(doubled.diameter, 2 * 358 * 0.36, accuracy: 0.01)
    }
}

final class HistoryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("GrooveyTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func track(_ title: String) -> Track {
        Track(title: title, artist: "Artist", album: "Album", duration: 100, elapsed: 0, timestamp: Date(), isPlaying: true, bundleID: "b")
    }

    func testNewestFirstWithoutDuplicates() {
        let store = HistoryStore(directory: directory)
        store.record(track("One"))
        store.record(track("Two"))
        store.record(track("Two"))
        store.record(track("One"))
        XCTAssertEqual(store.entries.map(\.title), ["One", "Two"])
    }

    func testCapacityIsEnforced() {
        let store = HistoryStore(directory: directory)
        for index in 0..<(HistoryStore.capacity + 5) { store.record(track("Song \(index)")) }
        XCTAssertEqual(store.entries.count, HistoryStore.capacity)
        XCTAssertEqual(store.entries.first?.title, "Song \(HistoryStore.capacity + 4)")
    }

    func testPersistsAcrossInstancesAndClears() {
        let first = HistoryStore(directory: directory)
        first.record(track("Kept"))
        let second = HistoryStore(directory: directory)
        XCTAssertEqual(second.entries.map(\.title), ["Kept"])
        second.clear()
        XCTAssertTrue(HistoryStore(directory: directory).entries.isEmpty)
    }

    func testArtworkIsSavedWhenItArrivesLate() throws {
        let store = HistoryStore(directory: directory)
        var song = track("Cover")
        store.record(song)
        XCTAssertNil(store.entries.first?.artworkFile)

        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        song.artwork = try XCTUnwrap(image.tiffRepresentation)
        store.record(song)

        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertNotNil(entry.artworkFile)
        XCTAssertNotNil(store.image(for: entry))
    }
}

final class SourceFilterTests: XCTestCase {
    func testFilters() {
        XCTAssertTrue(SourceFilter.any.accepts(bundleID: "anything"))
        XCTAssertTrue(SourceFilter.spotify.accepts(bundleID: "com.spotify.client"))
        XCTAssertFalse(SourceFilter.spotify.accepts(bundleID: "com.apple.Music"))
        XCTAssertTrue(SourceFilter.appleMusic.accepts(bundleID: "com.apple.Music"))
    }
}
