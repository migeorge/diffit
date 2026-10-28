import AppKit
import SwiftUI

@main
struct DiffItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The main window is owned by AppDelegate so it can be reopened from an IPC message.
        Settings {
            SettingsView()
                .environment(AppSettings.shared)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Install Command Line Tool") { Task { await CLIInstaller.shared.install() } }
                    .disabled(!CLIInstaller.shared.canInstall)
                Button("Remove Command Line Tool…") { CLIInstaller.shared.confirmRemove() }
                    .disabled(!CLIInstaller.shared.isPresent || CLIInstaller.shared.isBusy)
            }
            CommandGroup(after: .saveItem) {
                Button("Close Changeset") { AppModel.shared.closeSelectedChangeSet() }
                    .keyboardShortcut("w", modifiers: [.shift, .command])
                    .disabled(AppModel.shared.changeSets.isEmpty)
                Button("Reload") { AppModel.shared.reloadSelected() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(AppModel.shared.selectedEntry == nil)
                Divider()
                Button("Reveal in Finder") {
                    if let side = AppModel.shared.selectedEntry?.liveSide { FileActions.revealInFinder(side) }
                }
                .keyboardShortcut("r", modifiers: [.shift, .command])
                .disabled(AppModel.shared.selectedEntry?.liveSide == nil)
                Button("Open in Default Editor") {
                    if let side = AppModel.shared.selectedEntry?.liveSide { FileActions.openInDefaultEditor(side) }
                }
                .keyboardShortcut("o", modifiers: [.shift, .command])
                .disabled(AppModel.shared.selectedEntry?.liveSide == nil)
            }
            CommandGroup(before: .sidebar) {
                Button("Next Change") { AppModel.shared.activeNavigator?.nextChange() }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                    .disabled(AppModel.shared.changeNavigation.count == 0)
                Button("Previous Change") { AppModel.shared.activeNavigator?.previousChange() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    .disabled(AppModel.shared.changeNavigation.count == 0)
                Button("Other End of Move") { AppModel.shared.activeNavigator?.jumpToMoveCounterpart() }
                    .keyboardShortcut("m", modifiers: [.shift, .command])
                    .disabled(!AppModel.shared.changeNavigation.currentIsMove)
                Button("Next File") { AppModel.shared.selectNextFile() }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                    .disabled(AppModel.shared.changeSets.isEmpty)
                Button("Previous File") { AppModel.shared.selectPreviousFile() }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                    .disabled(AppModel.shared.changeSets.isEmpty)
                Divider()
                Button("Bigger Text") { AppSettings.shared.increaseFontSize() }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(!AppSettings.shared.canIncreaseFontSize)
                Button("Smaller Text") { AppSettings.shared.decreaseFontSize() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(!AppSettings.shared.canDecreaseFontSize)
                Divider()
                // The hosted NavigationSplitView answers NSSplitViewController's action through
                // the responder chain; SwiftUI adds this item only for its own window scenes.
                Button("Toggle Sidebar") {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("s", modifiers: [.control, .command])
                Divider()
            }
        }
    }
}
