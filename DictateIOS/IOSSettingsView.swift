#if os(iOS)
import SwiftUI
import DictateCore

struct IOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var geminiKey = ""
    @State private var deepgramKey = ""
    @State private var geminiSaved = false
    @State private var deepgramSaved = false

    private let keychainService = KeychainService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Gemini API Key (必須)") {
                    SecureField("APIキーを入力", text: $geminiKey)
                    Button("保存") {
                        try? keychainService.save(key: KeychainService.geminiKeyName, value: geminiKey)
                        GeminiServiceManager.initialize(apiKey: geminiKey)
                        geminiKey = ""
                        geminiSaved = true
                    }
                    .disabled(geminiKey.isEmpty)
                    if geminiSaved {
                        Label("保存済み", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Section("Deepgram API Key (オプション)") {
                    SecureField("APIキーを入力", text: $deepgramKey)
                    Button("保存") {
                        try? keychainService.save(key: KeychainService.deepgramKeyName, value: deepgramKey)
                        deepgramKey = ""
                        deepgramSaved = true
                    }
                    .disabled(deepgramKey.isEmpty)
                    if deepgramSaved {
                        Label("保存済み", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    Text("リアルタイムプレビュー用。なくても動作します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
#endif
