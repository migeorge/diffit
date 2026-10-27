import SwiftUI

@main
struct DiffItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The main window is owned by AppDelegate so it can be reopened from an IPC message.
        Settings {
            Text("Settings")
                .padding()
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("Close Changeset") { AppModel.shared.closeSelectedChangeSet() }
                    .keyboardShortcut("w", modifiers: [.shift, .command])
                    .disabled(AppModel.shared.changeSets.isEmpty)
                Button("Reload") { AppModel.shared.reloadSelected() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(AppModel.shared.selectedEntry == nil)
            }
            CommandMenu("Navigate") {
                Button("Next File") { AppModel.shared.selectNextFile() }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                Button("Previous File") { AppModel.shared.selectPreviousFile() }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
            }
        }
    }
}
