import SwiftUI
import DictateCore

@main
struct DictateApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(nsImage: Self.menuBarIcon(for: appState.status))
        }

        Settings {
            SettingsView(appState: appState)
        }
    }

    /// Build a template NSImage for the menu bar.
    /// Uses the custom tray-icon during idle, and SF Symbols for other states.
    private static func menuBarIcon(for status: AppState.Status) -> NSImage {
        let img: NSImage
        switch status {
        case .idle:
            if let bundled = Bundle.module.image(forResource: "tray-icon") {
                img = bundled
            } else {
                // Fallback to SF Symbol if resource not found
                img = NSImage(systemSymbolName: "mic", accessibilityDescription: "Dictate") ?? NSImage()
            }
        case .recording:
            img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Recording") ?? NSImage()
        case .processing:
            img = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Processing") ?? NSImage()
        case .typing:
            img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Typing") ?? NSImage()
        case .error:
            img = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error") ?? NSImage()
        }
        img.isTemplate = true
        img.size = NSSize(width: 18, height: 18)
        return img
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
