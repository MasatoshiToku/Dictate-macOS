import Testing
import Foundation
@testable import DictateCore

@Suite("HistoryService")
struct HistoryServiceTests {
    @Test("Add and retrieve history entry")
    func addAndRetrieve() {
        let service = HistoryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-history-\(UUID().uuidString).json"))
        service.add(originalText: "えーっと東京タワー", formattedText: "東京タワー")

        let all = service.getAll()
        #expect(all.count == 1)
        #expect(all[0].originalText == "えーっと東京タワー")
        #expect(all[0].formattedText == "東京タワー")
    }

    @Test("Search history")
    func searchHistory() {
        let service = HistoryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-history-\(UUID().uuidString).json"))
        service.add(originalText: "東京タワー", formattedText: "東京タワー")
        service.add(originalText: "大阪城", formattedText: "大阪城")

        let results = service.search(query: "東京")
        #expect(results.count == 1)
        #expect(results[0].formattedText == "東京タワー")
    }

    @Test("Delete single entry")
    func deleteEntry() {
        let service = HistoryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-history-\(UUID().uuidString).json"))
        service.add(originalText: "test", formattedText: "test")
        let entry = service.getAll().first!
        let deleted = service.deleteEntry(id: entry.id)
        #expect(deleted == true)
        #expect(service.getAll().isEmpty)
    }

    @Test("Delete all entries")
    func deleteAll() {
        let service = HistoryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-history-\(UUID().uuidString).json"))
        service.add(originalText: "test1", formattedText: "test1")
        service.add(originalText: "test2", formattedText: "test2")
        service.deleteAll()
        #expect(service.getAll().isEmpty)
    }

    @Test("Entries ordered newest first")
    func ordering() {
        let service = HistoryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-history-\(UUID().uuidString).json"))
        service.add(originalText: "first", formattedText: "first")
        service.add(originalText: "second", formattedText: "second")

        let all = service.getAll()
        #expect(all[0].formattedText == "second")
        #expect(all[1].formattedText == "first")
    }

    @Test("History is trimmed to max 1000 entries")
    func historyLimit() {
        let service = HistoryService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("test-history-\(UUID().uuidString).json"))

        // Add 1005 entries
        for i in 0..<1005 {
            service.add(originalText: "text \(i)", formattedText: "formatted \(i)")
        }

        let all = service.getAll()
        #expect(all.count == 1000)

        // The newest entries should be kept (inserted at front)
        #expect(all.first?.formattedText == "formatted 1004")
    }
}
