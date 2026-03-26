import Testing
import Foundation
@testable import DictateCore

@Suite("DictionaryService")
struct DictionaryServiceTests {
    @Test("Add and retrieve entry")
    func addAndRetrieve() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        let entry = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        #expect(entry.reading == "とうきょう")
        #expect(entry.word == "東京")
        #expect(entry.category == .manual)
        #expect(entry.usageCount == 0)

        let all = service.getAll()
        #expect(all.count == 1)
        #expect(all[0].id == entry.id)
    }

    @Test("getByCategory filters correctly")
    func getByCategory() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dict-cat-\(UUID()).json")
        let service = DictionaryService(storageURL: url)
        try service.addEntry(reading: "てすと", word: "テスト", category: .manual)
        try service.addEntry(reading: "じどう", word: "自動", category: .auto)

        let manual = service.getByCategory(.manual)
        #expect(manual.count == 1)
        #expect(manual.first?.word == "テスト")

        let auto = service.getByCategory(.auto)
        #expect(auto.count == 1)
        #expect(auto.first?.word == "自動")
    }

    @Test("updateEntry modifies reading and word")
    func updateEntry() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dict-upd-\(UUID()).json")
        let service = DictionaryService(storageURL: url)
        let entry = try service.addEntry(reading: "old", word: "OLD", category: .manual)

        let updated = try service.updateEntry(id: entry.id, reading: "new", word: "NEW")
        #expect(updated == true)

        let all = service.getAll()
        #expect(all.first?.reading == "new")
        #expect(all.first?.word == "NEW")
    }

    @Test("updateEntry returns false for nonexistent id")
    func updateEntryNotFound() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dict-upd-nf-\(UUID()).json")
        let service = DictionaryService(storageURL: url)
        let result = try service.updateEntry(id: "nonexistent", reading: "x")
        #expect(result == false)
    }

    @Test("duplicate entry throws duplicateEntry error")
    func duplicateThrowsCorrectError() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dict-dup-\(UUID()).json")
        let service = DictionaryService(storageURL: url)
        try service.addEntry(reading: "test", word: "Test", category: .manual)

        #expect(throws: DictionaryService.DictionaryError.duplicateEntry) {
            try service.addEntry(reading: "test", word: "Test", category: .manual)
        }
    }

    @Test("Search entries")
    func searchEntries() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        _ = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        _ = try service.addEntry(reading: "おおさか", word: "大阪", category: .manual)

        let results = service.search(query: "とうきょう")
        #expect(results.count == 1)
        #expect(results[0].word == "東京")
    }

    @Test("Dictionary prompt generation")
    func dictionaryPrompt() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        _ = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        let prompt = service.getDictionaryPrompt()
        #expect(prompt.contains("とうきょう"))
        #expect(prompt.contains("東京"))
        #expect(prompt.contains("辞書"))
    }

    @Test("Empty dictionary returns empty prompt")
    func emptyPrompt() {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        let prompt = service.getDictionaryPrompt()
        #expect(prompt.isEmpty)
    }

    @Test("Delete entry")
    func deleteEntry() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        let entry = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        let deleted = service.deleteEntry(id: entry.id)
        #expect(deleted == true)
        #expect(service.getAll().isEmpty)
    }

    @Test("Increment usage count")
    func incrementUsage() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        let entry = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        service.incrementUsage(id: entry.id)
        let updated = service.getAll().first
        #expect(updated?.usageCount == 1)
    }

    @Test("Reject empty reading")
    func rejectEmptyReading() {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        #expect(throws: DictionaryService.DictionaryError.self) {
            try service.addEntry(reading: "", word: "test", category: .manual)
        }
    }

    @Test("Reject empty word")
    func rejectEmptyWord() {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        #expect(throws: DictionaryService.DictionaryError.self) {
            try service.addEntry(reading: "test", word: "", category: .manual)
        }
    }

    @Test("Reject whitespace-only input")
    func rejectWhitespaceOnly() {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        #expect(throws: DictionaryService.DictionaryError.self) {
            try service.addEntry(reading: "   ", word: "test", category: .manual)
        }
    }

    @Test("Reject reading over 100 characters")
    func rejectLongReading() {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        let longString = String(repeating: "あ", count: 101)
        #expect(throws: DictionaryService.DictionaryError.self) {
            try service.addEntry(reading: longString, word: "test", category: .manual)
        }
    }

    @Test("Accept reading at exactly 100 characters")
    func acceptMaxLengthReading() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        let maxString = String(repeating: "あ", count: 100)
        let entry = try service.addEntry(reading: maxString, word: "test", category: .manual)
        #expect(entry.reading.count == 100)
    }
}
