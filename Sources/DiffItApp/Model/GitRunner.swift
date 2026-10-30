import Foundation

/// Runs read-only git commands for the repository tracker, off the main actor.
struct GitRunner: Sendable {
    let executable: String
    let root: String

    struct Output: Sendable {
        var status: Int32
        var stdout: Data
        var stderr: String
    }

    /// Runs `git <arguments>` in the repository root. `GIT_OPTIONAL_LOCKS=0` keeps git from taking
    /// the index lock for its opportunistic refresh, so nothing the app runs writes to the repo.
    func run(_ arguments: [String], stdin: Data? = nil) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: root)
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        let stdoutPipe = Pipe(), stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let stdinPipe = stdin == nil ? nil : Pipe()
        process.standardInput = stdinPipe ?? FileHandle.nullDevice
        try process.run()
        if let stdinPipe, let stdin {
            DispatchQueue.global(qos: .utility).async {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: stdin)
                try? stdinPipe.fileHandleForWriting.close()
            }
        }
        // Both pipes are drained concurrently so neither can fill up and stall git.
        let stderrBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrBox.data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        let stderr = String(decoding: stderrBox.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return Output(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    /// The app is launched with launchd's minimal PATH, so the usual install locations are
    /// tried before it. The Command Line Tools' git comes before the `/usr/bin` shim, which
    /// routes through xcrun (slower, and refuses to run while an Xcode licence is unaccepted).
    static let executable: String? = {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let candidates = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/Library/Developer/CommandLineTools/usr/bin/git"]
            + path.split(separator: ":").map { "\($0)/git" }
            + ["/usr/bin/git"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }
}
