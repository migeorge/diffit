import Foundation

/// The CLI's only shell-outs. Each `run` costs ~5 ms, so callers avoid it on the hot path.
enum Git {
    /// `git rev-parse --show-toplevel`, or nil outside a repo / without git.
    static func topLevel() -> String? {
        guard let output = run(["rev-parse", "--show-toplevel"]), !output.isEmpty else { return nil }
        return output
    }

    // MARK: - Global difftool configuration

    static let toolName = "diffit"

    /// The `difftool.diffit.cmd` value for a tool at `cliPath`: an absolute path, so git finds it
    /// without `~/.local/bin` on PATH.
    static func command(for cliPath: String) -> String {
        "\"\(cliPath)\" \"$LOCAL\" \"$REMOTE\" \"$MERGED\""
    }

    struct Status {
        var tool: String?
        var command: String?
        var prompt: String?

        /// True when all three keys are set for the tool at `cliPath`.
        func isConfigured(for cliPath: String) -> Bool {
            tool == toolName && command == Git.command(for: cliPath) && prompt == "false"
        }
    }

    static func status() throws -> Status {
        guard isAvailable else { throw CLIError.failed("git not found") }
        return Status(tool: run(["config", "--global", "--get", "diff.tool"]),
                      command: run(["config", "--global", "--get", "difftool.\(toolName).cmd"]),
                      prompt: run(["config", "--global", "--get", "difftool.prompt"]))
    }

    /// Writes the global config that makes `git difftool` call the tool at `cliPath`; returns the lines set.
    static func configure(cliPath: String) throws -> [String] {
        let settings: [(String, String)] = [
            ("diff.tool", toolName),
            ("difftool.\(toolName).cmd", command(for: cliPath)),
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

    /// Removes what `configure` wrote. `difftool.prompt` is only unset when diffit was the tool,
    /// since another tool's setup may rely on it. Returns the keys unset.
    static func unconfigure() throws -> [String] {
        let current = try status()
        var removed: [String] = []
        func unset(_ key: String) throws {
            guard run(["config", "--global", "--unset", key]) != nil else {
                throw CLIError.failed("git config --global --unset \(key) failed")
            }
            removed.append(key)
        }
        if current.command != nil { try unset("difftool.\(toolName).cmd") }
        if current.tool == toolName {
            try unset("diff.tool")
            if current.prompt != nil { try unset("difftool.prompt") }
        }
        return removed
    }

    // MARK: - Private

    /// Runs git with `arguments`; returns trimmed stdout on exit 0, nil otherwise.
    private static func run(_ arguments: [String]) -> String? {
        guard let executable else { return nil }
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

    private static var isAvailable: Bool { executable != nil }

    /// First `git` on PATH, then the usual install locations (the app launches us with a minimal
    /// PATH), the Command Line Tools, then the Xcode shim.
    private static let executable: String? = {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let candidates = path.split(separator: ":").map { "\($0)/git" }
            + ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/Library/Developer/CommandLineTools/usr/bin/git", "/usr/bin/git"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()
}
