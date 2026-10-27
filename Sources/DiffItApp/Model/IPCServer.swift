import Foundation
import DiffItProtocol

/// Accepts CLI connections on a background queue; each decoded message is handed to the
/// main actor synchronously so the CLI's ack reflects whether ingest succeeded.
final class IPCServer {
    private let handler: @MainActor (OpenMessage) -> Ack
    private let queue = DispatchQueue(label: "dev.diffit.ipc", qos: .userInitiated)
    private var listener: Int32 = -1

    /// Clients that connect but never send a full line are dropped after this long.
    private static let requestTimeout: TimeInterval = 2

    init(handler: @escaping @MainActor (OpenMessage) -> Ack) {
        self.handler = handler
    }

    // MARK: - Lifecycle

    func start() throws {
        let url = DiffItPaths.socketURL()
        try DiffItPaths.ensureDirectory(url.deletingLastPathComponent())
        listener = try UnixSocket.listen(path: url.path)
        let fd = listener
        queue.async { [weak self] in
            while let client = try? UnixSocket.accept(fd) {
                self?.serve(client)
            }
        }
    }

    func stop() {
        guard listener >= 0 else { return }
        UnixSocket.close(listener)
        listener = -1
        unlink(DiffItPaths.socketURL().path)
    }

    deinit { stop() }

    // MARK: - Private

    private func serve(_ client: Int32) {
        defer { UnixSocket.close(client) }
        let ack: Ack
        do {
            guard let line = try UnixSocket.readLine(client, timeout: Self.requestTimeout) else { return }
            let message = try Wire.decode(OpenMessage.self, from: line)
            let handler = self.handler
            ack = DispatchQueue.main.sync {
                MainActor.assumeIsolated { handler(message) }
            }
        } catch {
            ack = Ack(ok: false, error: "bad request: \(error)")
        }
        try? UnixSocket.writeAll(client, try Wire.encodeLine(ack))
    }
}
