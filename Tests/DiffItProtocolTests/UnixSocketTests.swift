import Foundation
import Testing
@testable import DiffItProtocol

@Suite struct UnixSocketTests {
    private func temporarySocketPath() -> String {
        // Keep it short: sun_path is 104 bytes.
        "/tmp/diffit-test-\(UUID().uuidString.prefix(8)).sock"
    }

    @Test func connectToNothingReturnsNil() throws {
        #expect(try UnixSocket.connect(path: temporarySocketPath()) == nil)
    }

    @Test func pathTooLong() {
        let long = "/tmp/" + String(repeating: "x", count: 120)
        #expect(throws: UnixSocketError.pathTooLong) { try UnixSocket.connect(path: long) }
    }

    @Test func clientServerRoundTrip() async throws {
        let path = temporarySocketPath()
        let listener = try UnixSocket.listen(path: path)
        defer { UnixSocket.close(listener); unlink(path) }

        let message = OpenMessage(changeSetKey: "k", changeSetTitle: "t", startsNewChangeSet: true,
                                  expectedCount: nil, snapshotDirectory: nil,
                                  files: [FileMessage(displayPath: "a", old: nil, new: nil)])

        let server = Task.detached { () throws -> OpenMessage? in
            guard let client = try UnixSocket.accept(listener) else { return nil }
            defer { UnixSocket.close(client) }
            guard let line = try UnixSocket.readLine(client, timeout: 2) else { return nil }
            try UnixSocket.writeAll(client, try Wire.encodeLine(Ack(ok: true)))
            return try Wire.decode(OpenMessage.self, from: line)
        }

        let fd = try #require(try UnixSocket.connect(path: path))
        try UnixSocket.writeAll(fd, try Wire.encodeLine(message))
        let ackLine = try #require(try UnixSocket.readLine(fd, timeout: 2))
        #expect(try Wire.decode(Ack.self, from: ackLine) == Ack(ok: true))
        UnixSocket.close(fd)

        #expect(try await server.value == message)
    }

    @Test func staleSocketFileIsReplaced() throws {
        let path = temporarySocketPath()
        let first = try UnixSocket.listen(path: path)
        UnixSocket.close(first)                      // leaves the socket file behind, like a crash
        #expect(FileManager.default.fileExists(atPath: path))
        let second = try UnixSocket.listen(path: path)
        UnixSocket.close(second)
        unlink(path)
    }

    @Test func liveSocketIsNotStolen() throws {
        let path = temporarySocketPath()
        let first = try UnixSocket.listen(path: path)
        defer { UnixSocket.close(first); unlink(path) }
        #expect(throws: UnixSocketError.alreadyInUse) { try UnixSocket.listen(path: path) }
    }

    @Test func socketFileIsPrivate() throws {
        let path = temporarySocketPath()
        let fd = try UnixSocket.listen(path: path)
        defer { UnixSocket.close(fd); unlink(path) }
        let mode = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test func readLineTimesOut() throws {
        let path = temporarySocketPath()
        let listener = try UnixSocket.listen(path: path)
        defer { UnixSocket.close(listener); unlink(path) }
        let fd = try #require(try UnixSocket.connect(path: path))
        defer { UnixSocket.close(fd) }
        #expect(throws: UnixSocketError.timeout) { try UnixSocket.readLine(fd, timeout: 0.05) }
    }
}
