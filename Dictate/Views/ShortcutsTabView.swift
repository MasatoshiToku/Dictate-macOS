import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Default: Option + Space for toggle recording
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: .option))
    // No default for cancel recording — Escape is handled via NSEvent monitor (recording-only)
    // Users may assign a custom shortcut here for non-Escape cancel behavior
    static let cancelRecording = Self("cancelRecording")
    // Default: Option + Comma for open settings
    static let openSettings = Self("openSettings", default: .init(.comma, modifiers: .option))
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
