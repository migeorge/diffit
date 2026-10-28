import Foundation
import DiffItProtocol

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    /// Newest first.
    var changeSets: [ChangeSet] = []
    var selection: FileEntry.ID?

    /// Called when a message starts a new changeset; the app delegate shows and activates the window.
    @ObservationIgnored var onNewChangeSet: (() -> Void)?

    /// The pair view currently on screen, so menu commands can drive change navigation.
    @ObservationIgnored weak var activeNavigator: (any DiffNavigator)?

    var selectedEntry: FileEntry? {
        guard let selection else { return nil }
        for cs in changeSets {
            if let entry = cs.files.first(where: { $0.id == selection }) { return entry }
        }
        return nil
    }

    var selectedChangeSet: ChangeSet? {
        guard let selection else { return nil }
        return changeSets.first { cs in cs.files.contains { $0.id == selection } }
    }

    // MARK: - Ingest

    func ingest(_ message: OpenMessage) -> Ack {
        guard message.version == OpenMessage.currentVersion else {
            return Ack(ok: false, error: "diffit CLI protocol version \(message.version) does not match the app (\(OpenMessage.currentVersion)); run `make install`")
        }

        let changeSet: ChangeSet
        let isNew: Bool
        if !message.startsNewChangeSet, let existing = changeSets.first(where: { $0.key == message.changeSetKey }) {
            changeSet = existing
            isNew = false
        } else {
            changeSet = ChangeSet(key: message.changeSetKey,
                                  title: Self.title(message.changeSetTitle, at: Date()),
                                  expectedCount: message.expectedCount)
            changeSets.insert(changeSet, at: 0)
            isNew = true
        }
        if let dir = message.snapshotDirectory { changeSet.snapshotDirectories.insert(dir) }
        if let count = message.expectedCount { changeSet.expectedCount = count }

        var firstEntry: FileEntry?
        for file in message.files {
            let entry = FileEntry(displayPath: file.displayPath, old: file.old, new: file.new)
            _ = changeSet.upsert(entry)
            DiffLoader.load(entry)
            if firstEntry == nil { firstEntry = entry }
        }

        if isNew {
            selection = changeSet.orderedFiles.first?.id ?? firstEntry?.id
            onNewChangeSet?()
        }
        return Ack(ok: true)
    }

    static func title(_ base: String, at date: Date) -> String {
        "\(base) · \(date.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Closing

    /// Removes the changeset and deletes its snapshot directories (the app's own cache; never user files).
    func close(_ changeSet: ChangeSet) {
        guard let index = changeSets.firstIndex(where: { $0.id == changeSet.id }) else { return }
        let wasSelected = changeSet.files.contains { $0.id == selection }
        changeSets.remove(at: index)
        let fm = FileManager.default
        let root = DiffItPaths.snapshotsRoot().path
        for dir in changeSet.snapshotDirectories where dir.hasPrefix(root) {
            try? fm.removeItem(atPath: dir)
        }
        if wasSelected {
            selection = changeSets.first?.orderedFiles.first?.id
        }
    }

    func closeSelectedChangeSet() {
        if let cs = selectedChangeSet ?? changeSets.first { close(cs) }
    }

    // MARK: - Navigation

    private var allFiles: [FileEntry] { changeSets.flatMap(\.orderedFiles) }

    func selectNextFile() { step(by: 1) }
    func selectPreviousFile() { step(by: -1) }

    private func step(by delta: Int) {
        let files = allFiles
        guard !files.isEmpty else { return }
        guard let current = files.firstIndex(where: { $0.id == selection }) else {
            selection = files[0].id
            return
        }
        let next = current + delta
        guard files.indices.contains(next) else { return }
        selection = files[next].id
    }

    func reloadSelected() {
        if let entry = selectedEntry { DiffLoader.load(entry) }
    }
}
