import Foundation
import os

public final class DictionaryService: @unchecked Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "DictionaryService")
    private let storageURL: URL
    private var entries: [DictionaryEntry] = []
    private let lock = NSLock()

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? DictionaryService.defaultStorageURL()
        self.entries = self.loadFromDisk()
    }

    private static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dictateDir = appSupport.appendingPathComponent("Dictate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dictateDir, withIntermediateDirectories: true)
        return dictateDir.appendingPathComponent("dictionary.json")
    }

    public func getAll() -> [DictionaryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func getByCategory(_ category: DictionaryEntry.DictionaryCategory) -> [DictionaryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.category == category }
    }

    public func search(query: String) -> [DictionaryEntry] {
        lock.lock()
        defer { lock.unlock() }
        let lowerQuery = query.lowercased()
        return entries.filter {
            $0.reading.lowercased().contains(lowerQuery) ||
            $0.word.lowercased().contains(lowerQuery)
        }
    }

    @discardableResult
    public func addEntry(reading: String, word: String, category: DictionaryEntry.DictionaryCategory) throws -> DictionaryEntry {
        lock.lock()
        defer { lock.unlock() }

        if entries.contains(where: { $0.reading == reading && $0.word == word }) {
            throw DictionaryError.duplicateEntry
        }

        let entry = DictionaryEntry(
            id: UUID().uuidString,
            reading: reading,
            word: word,
            category: category,
            createdAt: Date(),
            usageCount: 0
        )
        entries.append(entry)
        saveToDisk()
        return entry
    }

    public func updateEntry(id: String, reading: String? = nil, word: String? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        if let reading { entries[index].reading = reading }
        if let word { entries[index].word = word }
        saveToDisk()
        return true
    }

    public func deleteEntry(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let before = entries.count
        entries.removeAll { $0.id == id }
        if entries.count < before {
            saveToDisk()
            return true
        }
        return false
    }

    public func incrementUsage(id: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].usageCount += 1
        saveToDisk()
    }

    public func getDictionaryPrompt() -> String {
        lock.lock()
        let currentEntries = entries
        lock.unlock()

        if currentEntries.isEmpty { return "" }
        let lines = currentEntries.map { "- \"\($0.reading)\" -> \"\($0.word)\"" }
        return """


        ## 辞書（参考情報のみ）
        注意: この辞書は音声に含まれている単語の表記を補助するためのものです。
        音声に含まれていない単語を辞書から推測して出力してはいけません。

        \(lines.joined(separator: "\n"))
        """
    }

    // MARK: - Persistence

    private func loadFromDisk() -> [DictionaryEntry] {
        do {
            guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
            let data = try Data(contentsOf: storageURL)
            return try JSONDecoder().decode([DictionaryEntry].self, from: data)
        } catch {
            logger.error("[DictionaryService] loadFromDisk: \(error.localizedDescription)")
            return []
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("[DictionaryService] saveToDisk: \(error.localizedDescription)")
        }
    }

    public enum DictionaryError: Error {
        case duplicateEntry
    }
}
