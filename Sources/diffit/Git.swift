import Foundation

/// The CLI's only shell-outs. Each `run` costs ~5 ms, so callers avoid it on the hot path.
enum Git {
    /// `git rev-parse --show-toplevel`, or nil outside a repo / without git.
    static func topLevel() -> String? {
        guard let output = run(["rev-parse", "--show-toplevel"]), !output.isEmpty else { return nil }
        return output
    }

    /// Writes the global config that makes `git difftool` call us; returns the lines it set.
    static func configure() throws -> [String] {
        let settings: [(String, String)] = [
            ("diff.tool", "diffit"),
            ("difftool.diffit.cmd", "diffit \"$LOCAL\" \"$REMOTE\" \"$MERGED\""),
            ("difftool.prompt", "false"),
        ]
        var lines: [String] = []
        for (key, value) in settings {
            guard run(["config", "--global", key, value]) != nil else {
                throw CLIError.failed("git config --global \(key) failed")
            }
            lines.append("\(key) = \(value)")
        }
        return lines
    }

    // MARK: - Private

    /// Runs git with `arguments`; returns trimmed stdout on exit 0, nil otherwise.
    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First `git` on PATH; `/usr/bin/git` (the Xcode shim) as a last resort.
    private static let executable: String = {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in path.split(separator: ":") {
            let candidate = "\(dir)/git"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return "/usr/bin/git"
    }()
}
