import Foundation
import DiffItProtocol

/// Connects to the running app, launching it if necessary, and delivers one message.
enum AppLauncher {
    private static let retryInterval: TimeInterval = 0.05
    private static let launchTimeout: TimeInterval = 8
    private static let ackTimeout: TimeInterval = 1

    /// Sends `message` and waits for the ack. A message that starts a changeset also brings the
    /// app to the front: a running app cannot activate itself on macOS 14 and later, but
    /// LaunchServices (`open`) can activate it on the user's behalf.
    static func send(_ message: OpenMessage) throws {
        let (fd, launched) = try connectLaunchingIfNeeded()
        defer { UnixSocket.close(fd) }
        try UnixSocket.writeAll(fd, try Wire.encodeLine(message))
        guard let line = try UnixSocket.readLine(fd, timeout: ackTimeout) else {
            throw CLIError.failed("DiffIt closed the connection without answering")
        }
        let ack = try Wire.decode(Ack.self, from: line)
        guard ack.ok else { throw CLIError.failed(ack.error ?? "DiffIt rejected the request") }
        // A fresh launch comes to the front by itself; a running app needs the nudge.
        if message.startsNewChangeSet, !launched { bringToFront() }
    }

    /// `diffit` with no arguments: bring the app up.
    static func activate() throws {
        if let fd = try UnixSocket.connect(path: DiffItPaths.socketURL().path) {
            UnixSocket.close(fd)
        }
        try launch()
    }

    // MARK: - Private

    /// Returns the socket and whether the app had to be launched for it.
    private static func connectLaunchingIfNeeded() throws -> (fd: Int32, launched: Bool) {
        let path = DiffItPaths.socketURL().path
        if let fd = try UnixSocket.connect(path: path) { return (fd, false) }
        try launch()
        let deadline = Date(timeIntervalSinceNow: launchTimeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: retryInterval)
            if let fd = try UnixSocket.connect(path: path) { return (fd, true) }
        }
        throw CLIError.failed("DiffIt did not start within \(Int(launchTimeout)) s (socket: \(path))")
    }

    /// `open -a "$DIFFIT_APP"` when set, else `open -b dev.diffit.app`, else `open -a DiffIt`.
    /// Launches in the foreground, so a first run appears without a second activation.
    private static func launch() throws {
        for args in openArguments() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = args
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

    /// Activates the running app through LaunchServices without waiting: the spawn costs about a
    /// millisecond, and the CLI has to return before git deletes its temp files.
    private static func bringToFront() {
        guard let args = openArguments().first else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// Ways to name the app for `open`, most specific first.
    private static func openArguments() -> [[String]] {
        let env = ProcessInfo.processInfo.environment
        var attempts: [[String]] = []
        if let custom = env["DIFFIT_APP"], !custom.isEmpty { attempts.append(["-a", custom]) }
        attempts.append(["-b", DiffItPaths.bundleIdentifier])
        attempts.append(["-a", "DiffIt"])
        return attempts
    }
}
