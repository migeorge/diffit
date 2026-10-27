import Foundation
import Testing
@testable import DiffItProtocol

@Suite struct MessagesTests {
    @Test func roundTrip() throws {
        let message = OpenMessage(
            changeSetKey: "/Users/x/repo", changeSetTitle: "repo", startsNewChangeSet: true,
            expectedCount: 3, snapshotDirectory: "/tmp/snap",
            files: [
                FileMessage(displayPath: "src/a.swift",
                            old: FileSide(path: "/tmp/snap/1-old-a.swift", isLive: false, label: "Original"),
                            new: FileSide(path: "/Users/x/repo/src/a.swift", isLive: true, label: "Working copy")),
                FileMessage(displayPath: "added.txt", old: nil, new: FileSide(path: "/x", isLive: true, label: "Working copy")),
            ]
        )
        let line = try Wire.encodeLine(message)
        #expect(line.last == 0x0A)
        #expect(line.dropLast().contains(0x0A) == false, "one JSON line")
        let decoded = try Wire.decode(OpenMessage.self, from: line.dropLast())
        #expect(decoded == message)
        #expect(decoded.version == OpenMessage.currentVersion)
    }

    @Test func slashesAreNotEscaped() throws {
        let line = try Wire.encodeLine(Ack(ok: false, error: "/dev/null"))
        #expect(String(decoding: line, as: UTF8.self).contains("/dev/null"))
    }

    @Test func ackDecoding() throws {
        let ok = try Wire.decode(Ack.self, from: Data("{\"ok\":true}".utf8))
        #expect(ok == Ack(ok: true))
        let bad = try Wire.decode(Ack.self, from: Data("{\"ok\":false,\"error\":\"nope\"}".utf8))
        #expect(bad == Ack(ok: false, error: "nope"))
    }
}
