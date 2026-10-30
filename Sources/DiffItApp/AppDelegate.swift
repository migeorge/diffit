import AppKit
import SwiftUI
import DiffItProtocol

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var ipcServer: IPCServer?
    /// The diff window, so ⌘W can tell it apart from Settings.
    private static weak var mainWindow: NSWindow?

    /// ⌘W: closes the active tab in the diff window, or the key window when it is another
    /// window (Settings) or no tab is open.
    static func closeTabOrWindow() {
        guard let key = NSApp.keyWindow else { return }
        if key === mainWindow, AppModel.shared.activeTabID != nil {
            AppModel.shared.closeActiveTab()
        } else {
            key.performClose(nil)
        }
    }

    /// Snapshot directories older than this are purged at launch.
    private static let snapshotMaxAge: TimeInterval = 7 * 24 * 3600

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` without a bundle.
        NSApp.setActivationPolicy(.regular)

        let model = AppModel.shared
        model.onNewChangeSet = { [weak self] in
            self?.showMainWindow()
            NSApp.activate()
        }
        startIPCServer(model: model)
        purgeOldSnapshots()
        showMainWindow()
        NSApp.activate()
        CLIInstaller.shared.refresh()
    }

    /// The link or git config may have changed in a terminal; re-check whenever we come forward.
    func applicationDidBecomeActive(_ notification: Notification) {
        CLIInstaller.shared.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    /// Closing the diff window quits: an app left running in the background would go on
    /// collecting changesets nobody looks at. The CLI relaunches it for the next diff.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.stopAllWatchers()
        // Nothing will show this session's snapshots again; delete them (the app's own cache).
        AppModel.shared.closeAllChangeSets()
        ipcServer?.stop()
    }

    // MARK: - Sidebar double-click

    /// A double-click on a sidebar row keeps its (preview) tab open. Detected from the window's
    /// events rather than with a gesture on the row: a tap gesture on a List row stops the List
    /// selecting on a single click. The sidebar's List is the only table view in the window.
    private func handleDoubleClick(_ event: NSEvent) {
        guard let window = event.window, window === self.window, let content = window.contentView,
              let hit = content.hitTest(content.convert(event.locationInWindow, from: nil)),
              hit.isInsideTableView else { return }
        AppModel.shared.pinActiveTab()
    }

    // MARK: - IPC

    private func startIPCServer(model: AppModel) {
        let server = IPCServer { message in model.ingest(message) }
        do {
            try server.start()
            ipcServer = server
        } catch UnixSocketError.alreadyInUse {
            NSLog("DiffIt: another instance owns \(DiffItPaths.socketURL().path); this one will not receive diffs")
        } catch {
            NSLog("DiffIt: could not start IPC server: \(error)")
        }
    }

    /// Removes snapshot directories left behind by earlier sessions (the app's own cache only).
    private func purgeOldSnapshots() {
        let root = DiffItPaths.snapshotsRoot()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Date(timeIntervalSinceNow: -Self.snapshotMaxAge)
        for dir in entries {
            let created = (try? dir.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if created < cutoff { try? fm.removeItem(at: dir) }
        }
    }

    // MARK: - Window

    func showMainWindow() {
        if window == nil {
            let root = MainView().environment(AppModel.shared).environment(AppSettings.shared)
            let hosting = NSHostingController(rootView: root)
            hosting.sceneBridgingOptions = [.toolbars, .title]
            let window = MainWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.onDoubleClick = { [weak self] event in self?.handleDoubleClick(event) }
            window.contentViewController = hosting
            window.toolbarStyle = .unified
            window.tabbingMode = .disallowed
            // Content comes from IPC, never from saved state; this also avoids the "reopen windows?"
            // prompt after a crash.
            window.isRestorable = false
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 900, height: 500)
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
            window.setFrameAutosaveName("DiffItMain")
            self.window = window
            Self.mainWindow = window
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

private extension NSView {
    var isInsideTableView: Bool {
        var view: NSView? = self
        while let current = view {
            if current is NSTableView { return true }
            view = current.superview
        }
        return false
    }
}

/// The diff window; reports double-clicks after dispatching them as usual.
final class MainWindow: NSWindow {
    var onDoubleClick: ((NSEvent) -> Void)?

    /// Watched on mouse-down: a table view tracks the mouse itself from its `mouseDown`, so the
    /// matching mouse-up never comes through `sendEvent` (nor through a local event monitor).
    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        if event.type == .leftMouseDown, event.clickCount == 2 { onDoubleClick?(event) }
    }
}
