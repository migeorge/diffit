import Foundation
import DiffItProtocol

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    /// Newest first.
    var changeSets: [ChangeSet] = []
    /// The sidebar's highlighted file. Setting it previews that file in a tab; it follows the
    /// active tab the other way round.
    var selection: FileEntry.ID? {
        didSet {
            guard selection != oldValue else { return }
            if let selection { open(selection, pin: false) }
            ensureSelectedIsWatched()
        }
    }

    /// The sidebar's highlighted row: `selection`, except for a moment after a changeset's tree
    /// restructured (a compressed directory chain splitting as files arrive). The outline view
    /// leaves a stale copy of the selected row behind when that row moves with the
    /// restructuring, so the highlight is lifted while the rows change and put back once they
    /// have settled; `selection` and the open tab are unaffected.
    var sidebarSelection: FileEntry.ID? { isRestructuring ? nil : selection }
    private var isRestructuring = false
    @ObservationIgnored private var settleTask: Task<Void, Never>?

    private func liftSidebarHighlight() {
        isRestructuring = true
        settleTask?.cancel()
        settleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.isRestructuring = false
        }
    }

    /// Open files, in tab-bar order.
    var tabs: [DiffTab] = []
    var activeTabID: DiffTab.ID? {
        didSet {
            guard activeTabID != oldValue else { return }
            if let tab = activeTab, selection != tab.entryID { selection = tab.entryID }
        }
    }

    /// Descriptor budget: beyond this many watched files, only the selected file is watched.
    static let watcherLimit = 1_000
    private var watchedCount = 0

    /// Called when a message starts a new changeset; the app delegate shows and activates the window.
    @ObservationIgnored var onNewChangeSet: (() -> Void)?

    /// The pair view currently on screen, so menu commands can drive change navigation.
    @ObservationIgnored weak var activeNavigator: (any DiffNavigator)? {
        didSet { hasActiveNavigator = activeNavigator != nil }
    }
    /// Observable mirror of `activeNavigator` for menu enabling.
    var hasActiveNavigator = false
    /// Mirror of the navigator's position for the toolbar indicator and menu enabling.
    var changeNavigation = ChangeNavigationState.none

    /// The file in the active tab.
    var selectedEntry: FileEntry? {
        activeTab.flatMap { entry(for: $0) }
    }

    var selectedChangeSet: ChangeSet? {
        guard let id = activeTab?.entryID else { return nil }
        return changeSets.first { cs in cs.files.contains { $0.id == id } }
    }

    var activeTab: DiffTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    func entry(for tab: DiffTab) -> FileEntry? {
        entry(withID: tab.entryID)
    }

    private func entry(withID id: FileEntry.ID) -> FileEntry? {
        for cs in changeSets {
            if let entry = cs.files.first(where: { $0.id == id }) { return entry }
        }
        return nil
    }

    // MARK: - Tabs

    /// Shows `entryID` in a tab: the one it is already in, else the preview tab (retargeted),
    /// else a new tab after the active one. `pin` keeps the tab open past the next preview.
    func open(_ entryID: FileEntry.ID, pin: Bool) {
        if let index = tabs.firstIndex(where: { $0.entryID == entryID }) {
            if pin { tabs[index].isPreview = false }
            activeTabID = tabs[index].id
        } else if !pin, let index = tabs.firstIndex(where: \.isPreview) {
            tabs[index].entryID = entryID
            activeTabID = tabs[index].id
        } else {
            let tab = DiffTab(entryID: entryID, isPreview: !pin)
            let position = activeTabID.flatMap { id in tabs.firstIndex { $0.id == id } }.map { $0 + 1 } ?? tabs.count
            tabs.insert(tab, at: position)
            activeTabID = tab.id
        }
        if selection != entryID { selection = entryID }
    }

    func activateTab(_ id: DiffTab.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    /// Keeps a preview tab open.
    func pinTab(_ id: DiffTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].isPreview = false
    }

    func pinActiveTab() {
        if let activeTabID { pinTab(activeTabID) }
    }

    /// Closes a tab; when it was active, the one after it (or before it) takes over.
    func closeTab(_ id: DiffTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if activeTabID == id {
            activeTabID = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)].id
            if activeTabID == nil { selection = nil }
        }
    }

    func closeActiveTab() {
        if let activeTabID { closeTab(activeTabID) }
    }

    func closeOtherTabs(than id: DiffTab.ID) {
        tabs.removeAll { $0.id != id }
        activeTabID = id
    }

    func selectNextTab() { stepTab(by: 1) }
    func selectPreviousTab() { stepTab(by: -1) }

    private func stepTab(by delta: Int) {
        guard !tabs.isEmpty, let current = tabs.firstIndex(where: { $0.id == activeTabID }) else {
            activeTabID = tabs.first?.id
            return
        }
        activeTabID = tabs[(current + delta + tabs.count) % tabs.count].id
    }

    /// Drops tabs whose files are gone (a closed changeset).
    private func removeTabs(for entries: [FileEntry]) {
        let gone = Set(entries.map(\.id))
        guard tabs.contains(where: { gone.contains($0.entryID) }) else { return }
        let activeIndex = tabs.firstIndex { $0.id == activeTabID } ?? 0
        let activeGone = activeTab.map { gone.contains($0.entryID) } ?? false
        tabs.removeAll { gone.contains($0.entryID) }
        if activeGone {
            activeTabID = tabs.isEmpty ? nil : tabs[min(activeIndex, tabs.count - 1)].id
        }
    }

    // MARK: - Ingest

    func ingest(_ message: OpenMessage) -> Ack {
        guard message.version == OpenMessage.currentVersion else {
            return Ack(ok: false, error: "diffit CLI protocol version \(message.version) does not match the app (\(OpenMessage.currentVersion)); reinstall the command line tool from the DiffIt menu")
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
        let structureBefore = changeSet.structureKey
        for file in message.files {
            let entry = FileEntry(displayPath: file.displayPath, old: file.old, new: file.new)
            if let replaced = changeSet.upsert(entry) {
                stopWatching(replaced)
                // A tab showing the replaced file shows its replacement.
                for index in tabs.indices where tabs[index].entryID == replaced.id { tabs[index].entryID = entry.id }
                if selection == replaced.id { selection = entry.id }
            }
            DiffLoader.load(entry)
            if watchedCount < Self.watcherLimit { startWatching(entry) }
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

    /// Removes the changeset, stops its watchers and deletes its snapshot directories
    /// (the app's own cache; never user files).
    func close(_ changeSet: ChangeSet) {
        guard let index = changeSets.firstIndex(where: { $0.id == changeSet.id }) else { return }
        changeSets.remove(at: index)
        for entry in changeSet.files { stopWatching(entry) }
        removeTabs(for: changeSet.files)
        let fm = FileManager.default
        let root = DiffItPaths.snapshotsRoot().path
        for dir in changeSet.snapshotDirectories where dir.hasPrefix(root) {
            try? fm.removeItem(atPath: dir)
        }
        if tabs.isEmpty {
            selection = changeSets.first?.orderedFiles.first?.id
        }
    }

    func closeSelectedChangeSet() {
        if let cs = selectedChangeSet ?? changeSets.first { close(cs) }
    }

    // MARK: - Watching

    /// Starts one watcher per live side. A change reloads the diff; a vanished file keeps the
    /// last diff and surfaces an error while the watcher keeps polling for its return.
    private func startWatching(_ entry: FileEntry) {
        guard entry.watchers.isEmpty else { return }
        for side in entry.liveSides {
            let watcher = FileWatcher(
                path: side.path,
                onChange: { Task { @MainActor in DiffLoader.load(entry) } },
                onMissing: { Task { @MainActor in entry.error = "File removed: \(side.path)" } }
            )
            if watcher.start() {
                entry.watchers.append(watcher)
            } else {
                entry.error = "Cannot watch \(side.path)"
            }
        }
        if !entry.watchers.isEmpty { watchedCount += 1 }
    }

    private func stopWatching(_ entry: FileEntry) {
        guard !entry.watchers.isEmpty else { return }
        for watcher in entry.watchers { watcher.stop() }
        entry.watchers = []
        watchedCount -= 1
    }

    /// Over the descriptor budget, files are only watched while selected.
    private func ensureSelectedIsWatched() {
        guard let entry = selectedEntry, !entry.isWatched, !entry.liveSides.isEmpty else { return }
        startWatching(entry)
        DiffLoader.load(entry)   // it may have changed while unwatched
    }

    func stopAllWatchers() {
        for cs in changeSets { for entry in cs.files { stopWatching(entry) } }
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

    /// Re-diffs every loaded file (a diff option changed).
    func reloadAll() {
        for entry in allFiles where entry.result != nil { DiffLoader.load(entry) }
    }

    /// Reloads the selected file, starting its watchers if it is over the budget and unwatched.
    func reloadSelected() {
        guard let entry = selectedEntry else { return }
        if !entry.isWatched, !entry.liveSides.isEmpty, watchedCount < Self.watcherLimit {
            startWatching(entry)
        }
        DiffLoader.load(entry)
    }
}
