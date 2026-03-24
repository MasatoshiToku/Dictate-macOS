import Testing
import Foundation
@testable import DictateCore

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("Default values match expectations")
    func defaultValues() {
        let settings = AppSettings()
        #expect(settings.recordingMode == .toggle)
        #expect(settings.typingSpeed == .fast)
        #expect(settings.language == .ja)
        #expect(settings.autoLaunch == false)
        #expect(settings.showInMenuBar == true)
    }

    @Test("Encoding and decoding roundtrip")
    func codableRoundtrip() throws {
        var settings = AppSettings()
        settings.recordingMode = .pushToTalk
        settings.typingSpeed = .natural
        settings.language = .en

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.recordingMode == .pushToTalk)
        #expect(decoded.typingSpeed == .natural)
        #expect(decoded.language == .en)
    }

    // MARK: - Language enum raw values

    @Test("Language enum raw values match expected strings")
    func languageRawValues() {
        #expect(TranscriptionLanguage.ja.rawValue == "ja")
        #expect(TranscriptionLanguage.en.rawValue == "en")
        #expect(TranscriptionLanguage.auto.rawValue == "auto")
    }

    @Test("Language enum has exactly 3 cases")
    func languageCaseCount() {
        #expect(TranscriptionLanguage.allCases.count == 3)
    }

    // MARK: - RecordingMode enum cases

    @Test("RecordingMode enum raw values")
    func recordingModeRawValues() {
        #expect(RecordingMode.toggle.rawValue == "toggle")
        #expect(RecordingMode.pushToTalk.rawValue == "push-to-talk")
    }

    @Test("RecordingMode has exactly 2 cases")
    func recordingModeCaseCount() {
        #expect(RecordingMode.allCases.count == 2)
    }

    // MARK: - TypingSpeed enum cases

    @Test("TypingSpeed enum raw values and delay")
    func typingSpeedRawValuesAndDelay() {
        #expect(TypingSpeed.instant.rawValue == "instant")
        #expect(TypingSpeed.fast.rawValue == "fast")
        #expect(TypingSpeed.natural.rawValue == "natural")

        #expect(TypingSpeed.instant.delayMs == 0)
        #expect(TypingSpeed.fast.delayMs == 10)
        #expect(TypingSpeed.natural.delayMs == 50)
    }

    @Test("TypingSpeed has exactly 3 cases")
    func typingSpeedCaseCount() {
        #expect(TypingSpeed.allCases.count == 3)
    }

    // MARK: - Full roundtrip with all properties

    @Test("Save and load preserves all settings")
    func fullRoundtrip() throws {
        var settings = AppSettings()
        settings.recordingMode = .pushToTalk
        settings.typingSpeed = .natural
        settings.language = .en
        settings.autoLaunch = true
        settings.showInMenuBar = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(decoded.recordingMode == .pushToTalk)
        #expect(decoded.typingSpeed == .natural)
        #expect(decoded.language == .en)
        #expect(decoded.autoLaunch == true)
        #expect(decoded.showInMenuBar == false)
    }

    @Test("Double roundtrip is idempotent")
    func doubleRoundtrip() throws {
        var settings = AppSettings()
        settings.recordingMode = .pushToTalk
        settings.typingSpeed = .instant
        settings.language = .auto
        settings.autoLaunch = true
        settings.showInMenuBar = false

        let data1 = try JSONEncoder().encode(settings)
        let decoded1 = try JSONDecoder().decode(AppSettings.self, from: data1)
        let data2 = try JSONEncoder().encode(decoded1)
        let decoded2 = try JSONDecoder().decode(AppSettings.self, from: data2)

        #expect(decoded1 == decoded2)
    }

    // MARK: - Changing one setting doesn't affect others

    @Test("Changing recordingMode does not affect other properties")
    func changeRecordingModeOnly() {
        let original = AppSettings()
        var modified = original
        modified.recordingMode = .pushToTalk

        #expect(modified.typingSpeed == original.typingSpeed)
        #expect(modified.language == original.language)
        #expect(modified.autoLaunch == original.autoLaunch)
        #expect(modified.showInMenuBar == original.showInMenuBar)
        #expect(modified.recordingMode != original.recordingMode)
    }

    @Test("Changing typingSpeed does not affect other properties")
    func changeTypingSpeedOnly() {
        let original = AppSettings()
        var modified = original
        modified.typingSpeed = .natural

        #expect(modified.recordingMode == original.recordingMode)
        #expect(modified.language == original.language)
        #expect(modified.autoLaunch == original.autoLaunch)
        #expect(modified.showInMenuBar == original.showInMenuBar)
        #expect(modified.typingSpeed != original.typingSpeed)
    }

    @Test("Changing language does not affect other properties")
    func changeLanguageOnly() {
        let original = AppSettings()
        var modified = original
        modified.language = .en

        #expect(modified.recordingMode == original.recordingMode)
        #expect(modified.typingSpeed == original.typingSpeed)
        #expect(modified.autoLaunch == original.autoLaunch)
        #expect(modified.showInMenuBar == original.showInMenuBar)
        #expect(modified.language != original.language)
    }

    @Test("Changing autoLaunch does not affect other properties")
    func changeAutoLaunchOnly() {
        let original = AppSettings()
        var modified = original
        modified.autoLaunch = true

        #expect(modified.recordingMode == original.recordingMode)
        #expect(modified.typingSpeed == original.typingSpeed)
        #expect(modified.language == original.language)
        #expect(modified.showInMenuBar == original.showInMenuBar)
        #expect(modified.autoLaunch != original.autoLaunch)
    }
}
