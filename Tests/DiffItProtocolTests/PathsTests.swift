import Foundation
import Testing
@testable import DiffItProtocol

@Suite struct PathsTests {
    @Test func locations() {
        #expect(DiffItPaths.supportDirectory().path.hasSuffix("/Library/Application Support/DiffIt"))
        #expect(DiffItPaths.snapshotsRoot().path.hasSuffix("/Library/Caches/DiffIt/snapshots"))
        #expect(DiffItPaths.socketURL().lastPathComponent == "diffit.sock")
        #expect(DiffItPaths.socketURL().path.utf8.count <= 103, "must fit sun_path")
    }

    @Test func ensureDirectoryIsPrivate() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("diffit-paths-\(UUID().uuidString)")
            .appendingPathComponent("nested")
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        try DiffItPaths.ensureDirectory(dir)
        try DiffItPaths.ensureDirectory(dir)   // idempotent
        let mode = try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int
        #expect(mode == 0o700)
    }
}
