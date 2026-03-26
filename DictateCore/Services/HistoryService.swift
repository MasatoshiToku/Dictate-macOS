import Foundation
import os

public final class HistoryService: @unchecked Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "HistoryService")
    private let storageURL: URL
    private var entries: [TranscriptionHistoryEntry] = []
    private let lock = NSLock()
    private static let maxEntries = 1000

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? HistoryService.defaultStorageURL()
        self.entries = self.loadFromDisk()
    }

    private static func defaultStorageURL() -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory
            let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("Dictate", isDirectory: true)
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            return tmpDir.appendingPathComponent("history.json")
        }
        let dictateDir = appSupport.appendingPathComponent("Dictate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dictateDir, withIntermediateDirectories: true)
        return dictateDir.appendingPathComponent("history.json")
    }

    public func getAll() -> [TranscriptionHistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func add(originalText: String, formattedText: String) {
        lock.lock()
        defer { lock.unlock() }
        let entry = TranscriptionHistoryEntry(
            id: UUID().uuidString,
            originalText: originalText,
            formattedText: formattedText,
            createdAt: Date()
        )
        entries.insert(entry, at: 0)

        // Trim oldest entries to prevent unbounded growth
        if entries.count > Self.maxEntries {
            let removed = entries.count - Self.maxEntries
            entries.removeLast(removed)
            logger.info("[HistoryService] Trimmed \(removed) oldest entries (limit: \(Self.maxEntries))")
        }

        saveToDisk()
    }

    public func search(query: String) -> [TranscriptionHistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        let lowerQuery = query.lowercased()
        return entries.filter {
            $0.originalText.lowercased().contains(lowerQuery) ||
            $0.formattedText.lowercased().contains(lowerQuery)
        }
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

    public func deleteAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() -> [TranscriptionHistoryEntry] {
        do {
            guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
            let data = try Data(contentsOf: storageURL)
            return try JSONDecoder().decode([TranscriptionHistoryEntry].self, from: data)
        } catch {
            logger.error("[HistoryService] loadFromDisk: \(error.localizedDescription)")
            return []
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("[HistoryService] saveToDisk: \(error.localizedDescription)")
        }
    }
}
