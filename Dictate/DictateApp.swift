import SwiftUI
import DictateCore

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
                Divider()
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
                Button("Dismiss") {
                    appState.errorMessage = nil
                }
            }

            if !appState.lastTranscription.isEmpty {
                Divider()
                Text(appState.lastTranscription)
                    .font(.caption)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
                Button("Copy Last Result") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.lastTranscription, forType: .string)
                }
            }

            Divider()

            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Check for Updates...") {
                appState.updaterService.checkForUpdates()
            }
            .disabled(!appState.updaterService.canCheckForUpdates)

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
