import Foundation
import DiffItProtocol

/// Connects to the running app, launching it if necessary, and delivers one message.
enum AppLauncher {
    private static let retryInterval: TimeInterval = 0.05
    private static let launchTimeout: TimeInterval = 8
    private static let ackTimeout: TimeInterval = 1

    /// Sends `message` and waits for the ack.
    static func send(_ message: OpenMessage) throws {
        let fd = try connectLaunchingIfNeeded()
        defer { UnixSocket.close(fd) }
        try UnixSocket.writeAll(fd, try Wire.encodeLine(message))
        guard let line = try UnixSocket.readLine(fd, timeout: ackTimeout) else {
            throw CLIError.failed("DiffIt closed the connection without answering")
        }
        let ack = try Wire.decode(Ack.self, from: line)
        guard ack.ok else { throw CLIError.failed(ack.error ?? "DiffIt rejected the request") }
    }

    /// `diffit` with no arguments: bring the app up.
    static func activate() throws {
        if let fd = try UnixSocket.connect(path: DiffItPaths.socketURL().path) {
            UnixSocket.close(fd)
        }
        try launch()
    }

    // MARK: - Private

    private static func connectLaunchingIfNeeded() throws -> Int32 {
        let path = DiffItPaths.socketURL().path
        if let fd = try UnixSocket.connect(path: path) { return fd }
        try launch()
        let deadline = Date(timeIntervalSinceNow: launchTimeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: retryInterval)
            if let fd = try UnixSocket.connect(path: path) { return fd }
        }
        throw CLIError.failed("DiffIt did not start within \(Int(launchTimeout)) s (socket: \(path))")
    }

    /// `open -a "$DIFFIT_APP"` when set, else `open -b dev.diffit.app`, else `open -a DiffIt`.
    private static func launch() throws {
        let env = ProcessInfo.processInfo.environment
        var attempts: [[String]] = []
        if let custom = env["DIFFIT_APP"], !custom.isEmpty { attempts.append(["-a", custom]) }
        attempts.append(["-b", DiffItPaths.bundleIdentifier])
        attempts.append(["-a", "DiffIt"])
        for args in attempts {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-g"] + args   // -g: do not steal focus; the app activates itself when needed
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 { return }
            } catch {
                continue
            }
        }
        throw CLIError.failed("could not launch DiffIt.app (is it installed? set DIFFIT_APP to its path)")
    }
}
