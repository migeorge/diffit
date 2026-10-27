import SwiftUI

@main
struct DiffItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings")
                .padding()
        }
    }
}
