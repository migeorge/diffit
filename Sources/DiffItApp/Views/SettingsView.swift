import SwiftUI

/// The Settings window (⌘,). Every control writes straight through to `AppSettings`,
/// which persists it and bumps `version` so the open panes re-render.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Text") {
                Picker("Font", selection: $settings.fontFamily) {
                    Text("System monospaced").tag("")
                    Divider()
                    ForEach(AppSettings.monospacedFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                HStack {
                    Stepper("Size", value: $settings.fontSize, in: AppSettings.fontSizeRange, step: 1)
                    Text("\(Int(settings.fontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                Picker("Tab width", selection: $settings.tabWidth) {
                    ForEach(AppSettings.tabWidths, id: \.self) { width in
                        Text("\(width)").tag(width)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Diff") {
                Toggle("Highlight changed words within lines", isOn: $settings.intraLineHighlights)
                Toggle("Detect moved blocks", isOn: $settings.detectMoves)
                    .onChange(of: settings.detectMoves) { AppModel.shared.reloadAll() }
                Toggle("Hatch rows with no counterpart", isOn: $settings.showChangeHatch)
                Toggle("Wrap long lines", isOn: $settings.wrapLines)
                    .disabled(true)
                    .help("Not available yet: long lines scroll horizontally.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
