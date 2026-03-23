import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
    static let cancelRecording = Self("cancelRecording")
    static let openSettings = Self("openSettings")
}

struct ShortcutsTabView: View {
    var body: some View {
        Form {
            Section("Global Shortcuts") {
                KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
                KeyboardShortcuts.Recorder("Cancel Recording:", name: .cancelRecording)
                KeyboardShortcuts.Recorder("Open Settings:", name: .openSettings)
            }

            Section {
                Button("Reset to Defaults") {
                    KeyboardShortcuts.reset(.toggleRecording)
                    KeyboardShortcuts.reset(.cancelRecording)
                    KeyboardShortcuts.reset(.openSettings)
                }
            }
        }
        .formStyle(.grouped)
    }
}
