import SwiftUI

@main
struct DictateApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Dictate", systemImage: appState.menuBarIconName) {
            Text("Dictate - Voice Dictation")
                .padding()
            Divider()
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
