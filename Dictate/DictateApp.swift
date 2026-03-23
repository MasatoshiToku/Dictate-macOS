import SwiftUI

@main
struct DictateApp: App {
    var body: some Scene {
        MenuBarExtra("Dictate", systemImage: "mic.fill") {
            Text("Dictate - Voice Dictation")
                .padding()
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
