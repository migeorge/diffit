import Foundation
import DiffItProtocol

/// `diffit --stub-server`: a stand-in for the app during development. Listens on the real
/// socket path, prints every message it receives as pretty JSON, and acks it.
enum StubServer {
    static func run() throws -> Never {
        let url = DiffItPaths.socketURL()
        try DiffItPaths.ensureDirectory(url.deletingLastPathComponent())
        let listener = try UnixSocket.listen(path: url.path)
        print("stub server listening on \(url.path)")
        let printer = JSONEncoder()
        printer.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        while let client = try UnixSocket.accept(listener) {
            defer { UnixSocket.close(client) }
            guard let line = try UnixSocket.readLine(client, timeout: 5) else { continue }
            do {
                let message = try Wire.decode(OpenMessage.self, from: line)
                // Ack before printing so timing the CLI measures the hand-off, not stdout.
                try UnixSocket.writeAll(client, try Wire.encodeLine(Ack(ok: true)))
                print(String(decoding: try printer.encode(message), as: UTF8.self))
            } catch {
                print("bad message: \(error)")
                try UnixSocket.writeAll(client, try Wire.encodeLine(Ack(ok: false, error: "\(error)")))
            }
            fflush(stdout)
        }
        exit(0)
    }
}
