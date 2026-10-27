import Foundation
import DiffCore
import DiffItProtocol

/// Reads both sides of an entry off the main thread, diffs them, and publishes the result.
/// Loads for one entry are coalesced: a request during a running load runs once more after it.
@MainActor
enum DiffLoader {
    /// Sides above this many UTF-16 units skip intra-line highlighting.
    nonisolated static let intraLineLimit = 2_000_000

    private struct SideContent {
        var text: String
        var size: Int
        var isBinary: Bool
        var error: String?
    }

    private struct Outcome: Sendable {
        var result: DiffResult?
        var status: FileStatus?
        var error: String?
        var intraLineDisabled: Bool
        var oldSize: Int?
        var newSize: Int?
    }

    static func load(_ entry: FileEntry) {
        if entry.isLoading {
            entry.reloadRequested = true
            return
        }
        entry.isLoading = true
        let old = entry.old, new = entry.new
        Task.detached(priority: .userInitiated) {
            let outcome = compute(old: old, new: new)
            await MainActor.run { apply(outcome, to: entry) }
        }
    }

    // MARK: - Private

    private static func apply(_ outcome: Outcome, to entry: FileEntry) {
        entry.result = outcome.result
        if let status = outcome.status { entry.status = status }
        entry.error = outcome.error
        entry.intraLineDisabled = outcome.intraLineDisabled
        entry.oldSize = outcome.oldSize
        entry.newSize = outcome.newSize
        entry.generation += 1
        entry.isLoading = false
        if entry.reloadRequested {
            entry.reloadRequested = false
            load(entry)
        }
    }

    private nonisolated static func compute(old: FileSide?, new: FileSide?) -> Outcome {
        let oldContent = old.map(read), newContent = new.map(read)
        var outcome = Outcome(intraLineDisabled: false, oldSize: oldContent?.size, newSize: newContent?.size)
        outcome.error = oldContent?.error ?? newContent?.error

        if oldContent?.isBinary == true || newContent?.isBinary == true {
            outcome.status = .binary
            return outcome
        }
        // A side that failed to read is diffed as empty; the error is surfaced on the entry.
        var options = DiffOptions()
        let oldText = oldContent?.text ?? "", newText = newContent?.text ?? ""
        if oldText.utf16.count > intraLineLimit || newText.utf16.count > intraLineLimit {
            options.intraLine = false
            outcome.intraLineDisabled = true
        }
        outcome.result = DiffEngine.diff(old: oldText, new: newText, options: options)
        return outcome
    }

    private nonisolated static func read(_ side: FileSide) -> SideContent {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: side.path))
        } catch {
            let missing = !FileManager.default.fileExists(atPath: side.path)
            let message = missing ? "File removed: \(side.path)" : "Cannot read \(side.path): \(error.localizedDescription)"
            return SideContent(text: "", size: 0, isBinary: false, error: message)
        }
        if DiffEngine.isProbablyBinary(data) {
            return SideContent(text: "", size: data.count, isBinary: true, error: nil)
        }
        // UTF-8 first; ISO Latin-1 maps every byte, so it is the lossless fallback.
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)
        return SideContent(text: text, size: data.count, isBinary: false, error: nil)
    }
}
