import Foundation

/// Filesystem locations shared by the CLI and the app.
public enum DiffItPaths {
    public static let bundleIdentifier = "dev.diffit.app"
    public static let socketName = "diffit.sock"

    /// `sun_path` holds 104 bytes; stay comfortably below it.
    static let maxSocketPathLength = 100

    /// ~/Library/Application Support/DiffIt/
    public static func supportDirectory() -> URL {
        libraryDirectory(.applicationSupportDirectory).appendingPathComponent("DiffIt", isDirectory: true)
    }

    /// supportDirectory()/diffit.sock, or `$TMPDIR/diffit.sock` if that would exceed the sun_path limit.
    public static func socketURL() -> URL {
        let preferred = supportDirectory().appendingPathComponent(socketName)
        if preferred.path.utf8.count <= maxSocketPathLength { return preferred }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(socketName)
    }

    /// ~/Library/Caches/DiffIt/snapshots/
    public static func snapshotsRoot() -> URL {
        libraryDirectory(.cachesDirectory)
            .appendingPathComponent("DiffIt", isDirectory: true)
            .appendingPathComponent("snapshots", isDirectory: true)
    }

    /// Creates `url` (and parents) with mode 0700 if it does not exist.
    public static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    // MARK: - Private

    private static func libraryDirectory(_ kind: FileManager.SearchPathDirectory) -> URL {
        if let url = FileManager.default.urls(for: kind, in: .userDomainMask).first { return url }
        // Only reachable with a broken home directory; keep working somewhere writable.
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }
}
