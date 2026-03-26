import SwiftUI
import DictateCore

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
    @State private var showDeleteGeminiConfirm = false
    @State private var showDeleteDeepgramConfirm = false

    enum ValidationStatus {
        case none, validating, valid, saved, invalid(String)
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

                    if showGeminiKey {
                        Button("Save") {
                            saveGeminiKey()
                        }
                        .disabled(geminiKey.isEmpty)

                        Button("Cancel") {
                            showGeminiKey = false
                            geminiKey = ""
                            geminiStatus = .none
                        }
                    } else {
                        Button("Edit") {
                            showGeminiKey = true
                            geminiStatus = .none
                        }

                        if !geminiMasked.isEmpty {
                            Button("Delete", role: .destructive) {
                                showDeleteGeminiConfirm = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                statusView(geminiStatus)
            }

            Section("Deepgram API Key (Optional -- enables real-time preview)") {
                HStack {
                    if showDeepgramKey {
                        TextField("Enter Deepgram API key", text: $deepgramKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(deepgramMasked.isEmpty ? "Not configured" : deepgramMasked)
                            .foregroundColor(deepgramMasked.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if showDeepgramKey {
                        Button("Save") {
                            saveDeepgramKey()
                        }
                        .disabled(deepgramKey.isEmpty)

                        Button("Cancel") {
                            showDeepgramKey = false
                            deepgramKey = ""
                            deepgramStatus = .none
                        }
                    } else {
                        Button("Edit") {
                            showDeepgramKey = true
                            deepgramStatus = .none
                        }

                        if !deepgramMasked.isEmpty {
                            Button("Delete", role: .destructive) {
                                showDeleteDeepgramConfirm = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                statusView(deepgramStatus)
            }

            Section {
                Text("API keys are stored locally in UserDefaults and never sent to third parties.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            geminiMasked = keychainService.getMaskedValue(key: KeychainService.geminiKeyName) ?? ""
            deepgramMasked = keychainService.getMaskedValue(key: KeychainService.deepgramKeyName) ?? ""
        }
        .alert("Delete Gemini API Key?", isPresented: $showDeleteGeminiConfirm) {
            Button("Delete", role: .destructive) {
                deleteGeminiKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the Gemini API key. You will need to re-enter it to use dictation.")
        }
        .alert("Delete Deepgram API Key?", isPresented: $showDeleteDeepgramConfirm) {
            Button("Delete", role: .destructive) {
                deleteDeepgramKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the Deepgram API key. Real-time preview will be disabled.")
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
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
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
                geminiStatus = .saved
                showGeminiKey = false
                geminiKey = ""
                // Auto-clear status after delay
                try? await Task.sleep(for: .seconds(3))
                if case .saved = geminiStatus { geminiStatus = .none }
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
                    deepgramStatus = .saved
                    showDeepgramKey = false
                    deepgramKey = ""
                    // Auto-clear status after delay
                    try? await Task.sleep(for: .seconds(3))
                    if case .saved = deepgramStatus { deepgramStatus = .none }
                } else {
                    deepgramStatus = .invalid("Invalid API key")
                }
            } catch {
                deepgramStatus = .invalid(error.localizedDescription)
            }
        }
    }

    private func deleteGeminiKey() {
        do {
            try keychainService.delete(key: KeychainService.geminiKeyName)
            geminiMasked = ""
            geminiStatus = .none
        } catch {
            geminiStatus = .invalid("Failed to delete: \(error.localizedDescription)")
        }
    }

    private func deleteDeepgramKey() {
        do {
            try keychainService.delete(key: KeychainService.deepgramKeyName)
            deepgramMasked = ""
            deepgramStatus = .none
        } catch {
            deepgramStatus = .invalid("Failed to delete: \(error.localizedDescription)")
        }
    }
}
