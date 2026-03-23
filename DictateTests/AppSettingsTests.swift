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
}
