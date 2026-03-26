import SwiftUI
import DictateCore

struct SettingsView: View {
    let appState: AppState
    @State private var settings = AppSettings.load()

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Dictate v\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                APIKeyTabView(keychainService: appState.keychainService)
                    .tabItem { Label("API Keys", systemImage: "key") }

                GeneralTabView(settings: $settings)
                    .tabItem { Label("General", systemImage: "gear") }

                DictionaryTabView(dictionaryService: appState.dictionaryService)
                    .tabItem { Label("Dictionary", systemImage: "book") }

                HistoryTabView(historyService: appState.historyService)
                    .tabItem { Label("History", systemImage: "clock") }

                ShortcutsTabView()
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            }

            Divider()

            Text(versionString)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 6)
        }
        .frame(width: 600, height: 500)
    }
}
