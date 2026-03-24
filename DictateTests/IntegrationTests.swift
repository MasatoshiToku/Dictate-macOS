import Testing
import Foundation
@testable import DictateCore

@Suite("Integration")
struct IntegrationTests {

    // MARK: - DictionaryService prompt generation

    @Test("DictionaryService generates prompt containing all entries")
    func dictionaryPromptContainsAllEntries() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-integ-\(UUID().uuidString).json")
        let service = DictionaryService(storageURL: url)

        _ = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        _ = try service.addEntry(reading: "おおさか", word: "大阪", category: .manual)

        let prompt = service.getDictionaryPrompt()
        #expect(prompt.contains("とうきょう"))
        #expect(prompt.contains("東京"))
        #expect(prompt.contains("おおさか"))
        #expect(prompt.contains("大阪"))
        #expect(prompt.contains("辞書"))
    }

    @Test("Empty dictionary generates empty prompt for Gemini")
    func emptyDictionaryPrompt() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-integ-empty-\(UUID().uuidString).json")
        let service = DictionaryService(storageURL: url)
        let prompt = service.getDictionaryPrompt()
        #expect(prompt.isEmpty)
    }

    // MARK: - AppSettings idempotent roundtrip

    @Test("AppSettings save-load-save roundtrip is idempotent")
    func appSettingsIdempotentRoundtrip() throws {
        var settings = AppSettings()
        settings.recordingMode = .pushToTalk
        settings.typingSpeed = .instant
        settings.language = .auto
        settings.autoLaunch = true
        settings.showInMenuBar = false

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()

        // First roundtrip
        let data1 = try encoder.encode(settings)
        let decoded1 = try decoder.decode(AppSettings.self, from: data1)

        // Second roundtrip
        let data2 = try encoder.encode(decoded1)
        let decoded2 = try decoder.decode(AppSettings.self, from: data2)

        // Binary equality of JSON output
        #expect(data1 == data2, "JSON output should be identical across roundtrips")
        #expect(decoded1 == decoded2, "Decoded settings should be identical across roundtrips")
    }

    // MARK: - Storage isolation

    @Test("HistoryService and DictionaryService use independent storage")
    func storageIsolation() throws {
        let historyURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-history-iso-\(UUID().uuidString).json")
        let dictURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-iso-\(UUID().uuidString).json")

        let history = HistoryService(storageURL: historyURL)
        let dictionary = DictionaryService(storageURL: dictURL)

        // Add to history
        history.add(originalText: "hello world", formattedText: "Hello World")

        // Add to dictionary
        _ = try dictionary.addEntry(reading: "こんにちは", word: "こんにちは", category: .manual)

        // Verify history has its entry and not dictionary's
        let historyEntries = history.getAll()
        #expect(historyEntries.count == 1)
        #expect(historyEntries.first?.formattedText == "Hello World")

        // Verify dictionary has its entry and not history's
        let dictEntries = dictionary.getAll()
        #expect(dictEntries.count == 1)
        #expect(dictEntries.first?.word == "こんにちは")

        // Modifying one does not affect the other
        history.deleteAll()
        #expect(history.getAll().isEmpty)
        #expect(dictionary.getAll().count == 1, "Deleting history should not affect dictionary")
    }

    @Test("Multiple DictionaryService instances with same URL share data")
    func dictionaryServicePersistence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-persist-\(UUID().uuidString).json")

        // Instance 1 adds an entry
        let service1 = DictionaryService(storageURL: url)
        _ = try service1.addEntry(reading: "てすと", word: "テスト", category: .manual)

        // Instance 2 with same URL should load the entry
        let service2 = DictionaryService(storageURL: url)
        let entries = service2.getAll()
        #expect(entries.count == 1)
        #expect(entries.first?.word == "テスト")
    }

    @Test("Multiple HistoryService instances with same URL share data")
    func historyServicePersistence() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-history-persist-\(UUID().uuidString).json")

        // Instance 1 adds an entry
        let service1 = HistoryService(storageURL: url)
        service1.add(originalText: "test input", formattedText: "Test Input")

        // Instance 2 with same URL should load the entry
        let service2 = HistoryService(storageURL: url)
        let entries = service2.getAll()
        #expect(entries.count == 1)
        #expect(entries.first?.formattedText == "Test Input")
    }
}
