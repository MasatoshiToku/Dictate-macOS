import SwiftUI

struct APIKeyTabView: View {
    let keychainService: KeychainService
    @State private var geminiKey = ""
    @State private var deepgramKey = ""
    @State private var geminiMasked = ""
    @State private var deepgramMasked = ""
    @State private var geminiStatus: ValidationStatus = .none
    @State private var deepgramStatus: ValidationStatus = .none
    @State private var showGeminiKey = false
    @State private var showDeepgramKey = false

    enum ValidationStatus {
        case none, validating, valid, invalid(String)
    }

    var body: some View {
        Form {
            Section("Gemini API Key (Required)") {
                HStack {
                    if showGeminiKey {
                        TextField("Enter Gemini API key", text: $geminiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(geminiMasked.isEmpty ? "Not configured" : geminiMasked)
                            .foregroundColor(geminiMasked.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(showGeminiKey ? "Cancel" : "Edit") {
                        showGeminiKey.toggle()
                        if !showGeminiKey { geminiKey = "" }
                    }

                    if showGeminiKey {
                        Button("Save") {
                            saveGeminiKey()
                        }
                        .disabled(geminiKey.isEmpty)
                    }
                }

                statusView(geminiStatus)
            }

            Section("Deepgram API Key (Optional — enables real-time preview)") {
                HStack {
                    if showDeepgramKey {
                        TextField("Enter Deepgram API key", text: $deepgramKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(deepgramMasked.isEmpty ? "Not configured" : deepgramMasked)
                            .foregroundColor(deepgramMasked.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(showDeepgramKey ? "Cancel" : "Edit") {
                        showDeepgramKey.toggle()
                        if !showDeepgramKey { deepgramKey = "" }
                    }

                    if showDeepgramKey {
                        Button("Save") {
                            saveDeepgramKey()
                        }
                        .disabled(deepgramKey.isEmpty)
                    }
                }

                statusView(deepgramStatus)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            geminiMasked = keychainService.getMaskedValue(key: KeychainService.geminiKeyName) ?? ""
            deepgramMasked = keychainService.getMaskedValue(key: KeychainService.deepgramKeyName) ?? ""
        }
    }

    @ViewBuilder
    private func statusView(_ status: ValidationStatus) -> some View {
        switch status {
        case .none:
            EmptyView()
        case .validating:
            HStack {
                ProgressView().controlSize(.small)
                Text("Validating...")
            }
        case .valid:
            Label("Valid", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .invalid(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }

    private func saveGeminiKey() {
        geminiStatus = .validating
        let key = geminiKey
        Task {
            do {
                try keychainService.save(key: KeychainService.geminiKeyName, value: key)
                GeminiServiceManager.initialize(apiKey: key)
                geminiMasked = KeychainService.maskApiKey(key)
                geminiStatus = .valid
                showGeminiKey = false
                geminiKey = ""
            } catch {
                geminiStatus = .invalid(error.localizedDescription)
            }
        }
    }

    private func saveDeepgramKey() {
        deepgramStatus = .validating
        let key = deepgramKey
        Task {
            do {
                let valid = try await DeepgramService.validateApiKey(key)
                if valid {
                    try keychainService.save(key: KeychainService.deepgramKeyName, value: key)
                    deepgramMasked = KeychainService.maskApiKey(key)
                    deepgramStatus = .valid
                    showDeepgramKey = false
                    deepgramKey = ""
                } else {
                    deepgramStatus = .invalid("Invalid API key")
                }
            } catch {
                deepgramStatus = .invalid(error.localizedDescription)
            }
        }
    }
}
