import AppKit
import Foundation

/// Installs the bundled `diffit` command line tool: a symlink in `~/.local/bin` and git's global
/// `diff.tool` settings (written by the tool itself, so the CLI and the app agree on the format).
/// This is the one place the app writes outside its own directories, and only on the user's
/// explicit Install/Remove action.
@MainActor @Observable
final class CLIInstaller {
    static let shared = CLIInstaller()

    enum Status: Equatable {
        case unknown
        /// No `Contents/Helpers/diffit` next to the app (a `swift run` build).
        case unavailable
        case installed
        case incomplete(link: Bool, git: Bool)
    }

    var status: Status = .unknown
    var isBusy = false
    /// Outcome of the last install or remove, shown under the button.
    var message: String?

    /// `~/.local/bin/diffit`. `$HOME` first, as git resolves `~/.gitconfig`, so both land in the same home.
    nonisolated static let linkURL: URL = {
        let home = ProcessInfo.processInfo.environment["HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser
        return home.appending(path: ".local/bin/diffit")
    }()

    /// The CLI inside this app bundle, if the app is bundled.
    nonisolated static let toolURL: URL? = {
        let url = Bundle.main.bundleURL.appending(path: "Contents/Helpers/diffit")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }()

    /// Whether there is anything for Remove to undo.
    var isPresent: Bool {
        switch status {
        case .installed: return true
        case .incomplete(let link, let git): return link || git
        default: return false
        }
    }

    var canInstall: Bool {
        if case .incomplete = status { return !isBusy }
        return false
    }

    // MARK: - Actions

    func refresh() {
        guard !isBusy else { return }
        Task { status = await Task.detached { Self.probe() }.value }
    }

    func install() async {
        await perform(
            { try Self.installLink(); try Self.runTool("--git-config") },
            success: "Installed. git difftool now opens DiffIt. To run `diffit` by hand, add ~/.local/bin to your PATH.")
    }

    func remove() async {
        await perform(
            { try Self.removeLink(); try Self.runTool("--git-unconfig") },
            success: "Removed the command line tool link and git configuration.")
    }

    private func perform(_ work: @escaping @Sendable () throws -> Void, success: String) async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        let result = await Task.detached { () -> String? in
            do { try work(); return nil } catch { return "\(error)" }
        }.value
        status = await Task.detached { Self.probe() }.value
        message = result.map { "Failed: \($0)" } ?? success
        isBusy = false
    }

    // MARK: - Probing (off the main actor)

    nonisolated private static func probe() -> Status {
        guard let tool = toolURL else { return .unavailable }
        let link = linkPointsAtTool(tool)
        let git = (try? runTool("--git-check")) != nil
        return link && git ? .installed : .incomplete(link: link, git: git)
    }

    nonisolated private static func linkPointsAtTool(_ tool: URL) -> Bool {
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path) else { return false }
        let resolved = URL(fileURLWithPath: destination, relativeTo: linkURL.deletingLastPathComponent())
            .resolvingSymlinksInPath().path
        return resolved == tool.resolvingSymlinksInPath().path
    }

    nonisolated private static func installLink() throws {
        guard let tool = toolURL else { throw InstallError("this build has no bundled command line tool") }
        let fm = FileManager.default
        let link = linkURL
        try fm.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: link.path) || (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil {
            // Replace a symlink (ours or a stale one); never delete a real file the user put there.
            guard (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil else {
                throw InstallError("\(link.path) exists and is not a symlink; move it aside first")
            }
            try fm.removeItem(at: link)
        }
        try fm.createSymbolicLink(at: link, withDestinationURL: tool)
    }

    nonisolated private static func removeLink() throws {
        let fm = FileManager.default
        guard let destination = try? fm.destinationOfSymbolicLink(atPath: linkURL.path) else { return }
        // Only remove a link into a DiffIt bundle; leave anything else alone.
        guard destination.contains("DiffIt.app/Contents/Helpers/diffit") else {
            throw InstallError("\(linkURL.path) points elsewhere (\(destination)); left in place")
        }
        try fm.removeItem(at: linkURL)
    }

    /// Runs the bundled CLI with one flag; throws with its output on a non-zero exit.
    @discardableResult
    nonisolated private static func runTool(_ flag: String) throws -> String {
        guard let tool = toolURL else { throw InstallError("this build has no bundled command line tool") }
        let process = Process()
        process.executableURL = tool
        process.arguments = [flag]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else { throw InstallError(text.isEmpty ? "diffit \(flag) failed" : text) }
        return text
    }

    struct InstallError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    // MARK: - Confirmation

    /// Asks before removing; runs `remove()` on confirmation.
    func confirmRemove() {
        let alert = NSAlert()
        alert.messageText = "Remove the diffit command line tool?"
        alert.informativeText = "This deletes the ~/.local/bin/diffit link and unsets git's diff.tool, difftool.diffit.cmd and difftool.prompt. DiffIt itself stays installed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await remove() }
    }
}
