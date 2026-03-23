import SwiftUI

@main
struct DictateApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Dictate", systemImage: appState.menuBarIconName) {
            MenuBarView(appState: appState)
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}

struct MenuBarView: View {
    let appState: AppState

    var body: some View {
        VStack {
            Text("Dictate").font(.headline)
            Divider()

            Button(appState.status == .recording ? "Stop Recording" : "Start Recording") {
                appState.toggleRecording()
            }
            .disabled(appState.status == .processing || appState.status == .typing)

            if let error = appState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }

            Divider()

            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 4)
        .task {
            appState.initialize()
        }
    }
}
