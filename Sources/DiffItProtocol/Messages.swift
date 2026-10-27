import Foundation

/// One side of a file comparison.
public struct FileSide: Codable, Equatable, Sendable {
    /// Absolute path to read.
    public var path: String
    /// true = real working-tree file, watch it; false = snapshot owned by the app.
    public var isLive: Bool
    /// "Original", "Working copy", "HEAD", … (display only).
    public var label: String

    public init(path: String, isLive: Bool, label: String) {
        self.path = path
        self.isLive = isLive
        self.label = label
    }
}

public struct FileMessage: Codable, Equatable, Sendable {
    /// Repo-relative path, used for the tree.
    public var displayPath: String
    /// nil ⇒ file was added.
    public var old: FileSide?
    /// nil ⇒ file was deleted.
    public var new: FileSide?

    public init(displayPath: String, old: FileSide?, new: FileSide?) {
        self.displayPath = displayPath
        self.old = old
        self.new = new
    }
}

/// Newline-delimited JSON, UTF-8, one request per connection.
public struct OpenMessage: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    /// Repo root (or cwd) — groups invocations.
    public var changeSetKey: String
    /// e.g. "myrepo".
    public var changeSetTitle: String
    /// counter == 1 or no counter.
    public var startsNewChangeSet: Bool
    /// GIT_DIFF_PATH_TOTAL if present.
    public var expectedCount: Int?
    /// Directory the CLI created; the app deletes it when the changeset closes.
    public var snapshotDirectory: String?
    public var files: [FileMessage]

    public init(version: Int = OpenMessage.currentVersion, changeSetKey: String, changeSetTitle: String,
                startsNewChangeSet: Bool, expectedCount: Int?, snapshotDirectory: String?, files: [FileMessage]) {
        self.version = version
        self.changeSetKey = changeSetKey
        self.changeSetTitle = changeSetTitle
        self.startsNewChangeSet = startsNewChangeSet
        self.expectedCount = expectedCount
        self.snapshotDirectory = snapshotDirectory
        self.files = files
    }
}

public struct Ack: Codable, Equatable, Sendable {
    public var ok: Bool
    public var error: String?

    public init(ok: Bool, error: String? = nil) {
        self.ok = ok
        self.error = error
    }
}

// MARK: - Wire format

public enum Wire {
    /// Encodes one value as a single JSON line (no embedded newlines) terminated by `\n`.
    public static func encodeLine<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        try JSONDecoder().decode(type, from: line)
    }
}
