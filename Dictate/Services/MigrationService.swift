import Foundation
import os

// Electron -> Native data migration service
// Electron stores at ~/Library/Application Support/dictate/ (lowercase)
// Native stores at ~/Library/Application Support/Dictate/ (uppercase)
// Electron createdAt fields are Unix MILLISECONDS (JavaScript Date.now())
enum MigrationService {
    private static let logger = Logger(subsystem: "io.dictate.app", category: "migration")
    private static let hasMigratedKey = "hasMigratedFromElectron"

    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasMigratedKey) else { return }

        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let electronDir = appSupport.appendingPathComponent("dictate")  // lowercase
        let nativeDir = appSupport.appendingPathComponent("Dictate")    // uppercase

        // Electron data does not exist -- nothing to migrate
        guard fileManager.fileExists(atPath: electronDir.path) else {
            UserDefaults.standard.set(true, forKey: hasMigratedKey)
            return
        }

        // Ensure native directory exists
        try? fileManager.createDirectory(at: nativeDir, withIntermediateDirectories: true)

        migrateDictionary(from: electronDir, to: nativeDir)
        migrateHistory(from: electronDir, to: nativeDir)

        UserDefaults.standard.set(true, forKey: hasMigratedKey)
        logger.info("Migration from Electron completed")
    }

    // MARK: - Dictionary Migration

    private static func migrateDictionary(from electronDir: URL, to nativeDir: URL) {
        let sourcePath = electronDir.appendingPathComponent("dictionary.json")
        guard FileManager.default.fileExists(atPath: sourcePath.path) else { return }

        do {
            let data = try Data(contentsOf: sourcePath)

            // Electron format: { "entries": [...] }
            struct ElectronDictionaryStore: Decodable {
                let entries: [ElectronDictionaryEntry]
            }
            struct ElectronDictionaryEntry: Decodable {
                let id: String
                let reading: String
                let word: String
                let category: String
                let createdAt: Double   // milliseconds since epoch
                let usageCount: Int
            }

            let decoder = JSONDecoder()
            let store = try decoder.decode(ElectronDictionaryStore.self, from: data)

            // Convert to native format (flat [DictionaryEntry] array)
            let nativeEntries: [DictionaryEntry] = store.entries.map { e in
                DictionaryEntry(
                    id: e.id,
                    reading: e.reading,
                    word: e.word,
                    category: e.category == "manual" ? .manual : .auto,
                    createdAt: Date(timeIntervalSince1970: e.createdAt / 1000.0),
                    usageCount: e.usageCount
                )
            }

            let destPath = nativeDir.appendingPathComponent("dictionary.json")
            // Skip if native file already exists (don't overwrite user data)
            guard !FileManager.default.fileExists(atPath: destPath.path) else {
                logger.info("dictionary.json already exists in native dir, skipping")
                return
            }

            let nativeData = try JSONEncoder().encode(nativeEntries)
            try nativeData.write(to: destPath, options: .atomic)
            logger.info("Migrated \(nativeEntries.count) dictionary entries")
        } catch {
            logger.error("Dictionary migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - History Migration

    private static func migrateHistory(from electronDir: URL, to nativeDir: URL) {
        let sourcePath = electronDir.appendingPathComponent("history.json")
        guard FileManager.default.fileExists(atPath: sourcePath.path) else { return }

        do {
            let data = try Data(contentsOf: sourcePath)

            // Electron format: { "entries": [...] }
            struct ElectronHistoryStore: Decodable {
                let entries: [ElectronHistoryEntry]
            }
            struct ElectronHistoryEntry: Decodable {
                let id: String
                let originalText: String
                let formattedText: String
                let createdAt: Double   // milliseconds since epoch
            }

            let decoder = JSONDecoder()
            let store = try decoder.decode(ElectronHistoryStore.self, from: data)

            let nativeEntries: [TranscriptionHistoryEntry] = store.entries.map { e in
                TranscriptionHistoryEntry(
                    id: e.id,
                    originalText: e.originalText,
                    formattedText: e.formattedText,
                    createdAt: Date(timeIntervalSince1970: e.createdAt / 1000.0)
                )
            }

            let destPath = nativeDir.appendingPathComponent("history.json")
            // Skip if native file already exists
            guard !FileManager.default.fileExists(atPath: destPath.path) else {
                logger.info("history.json already exists in native dir, skipping")
                return
            }

            let nativeData = try JSONEncoder().encode(nativeEntries)
            try nativeData.write(to: destPath, options: .atomic)
            logger.info("Migrated \(nativeEntries.count) history entries")
        } catch {
            logger.error("History migration failed: \(error.localizedDescription)")
        }
    }
}
