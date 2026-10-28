import Foundation
import DiffCore
import DiffItProtocol
import SyntaxHighlight

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
        var isMissing = false
    }

    private struct Outcome: Sendable {
        var result: DiffResult?
        var status: FileStatus?
        var error: String?
        var intraLineDisabled: Bool
        var oldSize: Int?
        var newSize: Int?
        /// A live file is missing (mid-save or deleted): keep the last diff, show the error.
        var keepPrevious = false
        var lineMapping: [Int]?
        var oldSyntax: [HighlightSpan] = []
        var newSyntax: [HighlightSpan] = []
    }

    static func load(_ entry: FileEntry) {
        if entry.isLoading {
            entry.reloadRequested = true
            return
        }
        entry.isLoading = true
        let old = entry.old, new = entry.new
        let previousNewLines = entry.result?.newLines
        var options = DiffOptions()
        options.detectMoves = AppSettings.shared.detectMoves
        let path = entry.displayPath
        let highlight = AppSettings.shared.syntaxHighlighting
        Task.detached(priority: .userInitiated) {
            let outcome = compute(old: old, new: new, previousNewLines: previousNewLines, options: options,
                                  path: path, highlight: highlight)
            await MainActor.run { apply(outcome, to: entry) }
        }
    }

    // MARK: - Private

    private static func apply(_ outcome: Outcome, to entry: FileEntry) {
        entry.error = outcome.error
        if outcome.keepPrevious, entry.result != nil {
            entry.isLoading = false
            return
        }
        entry.result = outcome.result
        entry.newLineMapping = outcome.lineMapping
        entry.oldSyntax = outcome.oldSyntax
        entry.newSyntax = outcome.newSyntax
        if let status = outcome.status { entry.status = status }
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

    private nonisolated static func compute(old: FileSide?, new: FileSide?, previousNewLines: [String]?,
                                            options: DiffOptions, path: String, highlight: Bool) -> Outcome {
        let oldContent = old.map(read), newContent = new.map(read)
        var outcome = Outcome(intraLineDisabled: false, oldSize: oldContent?.size, newSize: newContent?.size)
        outcome.error = oldContent?.error ?? newContent?.error
        outcome.keepPrevious = oldContent?.isMissing == true || newContent?.isMissing == true

        if oldContent?.isBinary == true || newContent?.isBinary == true {
            outcome.status = .binary
            return outcome
        }
        // A side that failed to read is diffed as empty; the error is surfaced on the entry.
        var options = options
        let oldText = oldContent?.text ?? "", newText = newContent?.text ?? ""
        if oldText.utf16.count > intraLineLimit || newText.utf16.count > intraLineLimit {
            options.intraLine = false
            outcome.intraLineDisabled = true
        }
        let result = DiffEngine.diff(old: oldText, new: newText, options: options)
        outcome.result = result
        if let previousNewLines {
            outcome.lineMapping = DiffEngine.lineMapping(from: previousNewLines, to: result.newLines)
        }
        if highlight, let language = SyntaxLanguage.detect(path: path, firstLine: result.newLines.first ?? result.oldLines.first) {
            outcome.oldSyntax = SyntaxHighlighter.highlight(lines: result.oldLines, language: language)
            outcome.newSyntax = SyntaxHighlighter.highlight(lines: result.newLines, language: language)
        }
        return outcome
    }

    private nonisolated static func read(_ side: FileSide) -> SideContent {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: side.path))
        } catch {
            let missing = !FileManager.default.fileExists(atPath: side.path)
            let message = missing ? "File removed: \(side.path)" : "Cannot read \(side.path): \(error.localizedDescription)"
            return SideContent(text: "", size: 0, isBinary: false, error: message, isMissing: missing)
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
