import SwiftUI
import DictateCore
import ServiceManagement

struct GeneralTabView: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Recording Mode", selection: $settings.recordingMode) {
                    Text("Toggle (press once to start, once to stop)").tag(RecordingMode.toggle)
                    Text("Push-to-Talk (hold to record)").tag(RecordingMode.pushToTalk)
                }
                .onChange(of: settings.recordingMode) { _, _ in
                    // Notify AppState to re-register shortcuts for new mode
                    NotificationCenter.default.post(name: .recordingModeChanged, object: nil)
                }
            }

            Section("Typing") {
                Picker("Typing Speed", selection: $settings.typingSpeed) {
                    Text("Instant").tag(TypingSpeed.instant)
                    Text("Fast").tag(TypingSpeed.fast)
                    Text("Natural").tag(TypingSpeed.natural)
                }
            }

            Section("Language") {
                Picker("Transcription Language", selection: $settings.language) {
                    Text("Japanese").tag(TranscriptionLanguage.ja)
                    Text("English").tag(TranscriptionLanguage.en)
                    Text("Auto").tag(TranscriptionLanguage.auto)
                }
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $settings.autoLaunch)
                    .onChange(of: settings.autoLaunch) { _, newValue in
                        setLoginItem(enabled: newValue)
                    }
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if TextInputService.checkAccessibilityPermission() {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Grant Access") {
                            TextInputService.requestAccessibilityPermission()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings) { _, newValue in
            newValue.save()
        }
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[GeneralTabView] Login item error: \(error)")
        }
    }
}
