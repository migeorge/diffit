import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` without a bundle.
        NSApp.setActivationPolicy(.regular)
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

    // MARK: - Window

    func showMainWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: MainView())
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
