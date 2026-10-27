import AppKit
import SwiftUI
import DiffItProtocol

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var ipcServer: IPCServer?

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
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        ipcServer?.stop()
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
            let root = MainView().environment(AppModel.shared)
            let hosting = NSHostingController(rootView: root)
            hosting.sceneBridgingOptions = [.toolbars, .title]
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hosting
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 900, height: 500)
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
            window.setFrameAutosaveName("DiffItMain")
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
