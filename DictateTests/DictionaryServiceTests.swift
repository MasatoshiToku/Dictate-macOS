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

    @Test("Duplicate entry prevention")
    func duplicatePrevention() throws {
        let service = DictionaryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-dict-\(UUID().uuidString).json"))
        _ = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
        do {
            _ = try service.addEntry(reading: "とうきょう", word: "東京", category: .manual)
            Issue.record("Should have thrown duplicate error")
        } catch {
            // Expected
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
}
