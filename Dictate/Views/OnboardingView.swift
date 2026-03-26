import SwiftUI
import DictateCore

/// First-launch setup guide shown when no Gemini API key is configured.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var geminiKey = ""
    @State private var keyValid = false
    @State private var validating = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Dictate へようこそ")
                .font(.title)
                .bold()

            Text("AIが音声をリアルタイムで文字起こしし、\nアクティブなアプリに直接入力します。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            // API Key input
            VStack(alignment: .leading, spacing: 8) {
                Label("Gemini API Key を入力", systemImage: "key.fill")
                    .font(.headline)

                Text("Google AI Studio でAPIキーを取得してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    SecureField("API Key", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)

                    if validating {
                        ProgressView()
                            .controlSize(.small)
                    } else if keyValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button("保存して開始") {
                    saveAndStart()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(geminiKey.isEmpty || validating)
            }
            .padding()

            // Usage hint
            VStack(spacing: 4) {
                Text("使い方")
                    .font(.caption)
                    .bold()
                Text("Option + Space で録音開始/停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(32)
        .frame(width: 420, height: 460)
    }

    private func saveAndStart() {
        validating = true
        errorText = nil
        Task {
            do {
                let keychainService = KeychainService()
                try keychainService.save(key: KeychainService.geminiKeyName, value: geminiKey)

                GeminiServiceManager.initialize(apiKey: geminiKey)

                keyValid = true
                validating = false

                // Mark onboarding as done
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                try? await Task.sleep(for: .milliseconds(500))

                // Close the onboarding window via NSApp
                await MainActor.run {
                    // Find and close the onboarding window
                    for window in NSApp.windows {
                        if window.title == "Welcome to Dictate" {
                            window.close()
                            break
                        }
                    }
                }
            } catch {
                validating = false
                errorText = "保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}
