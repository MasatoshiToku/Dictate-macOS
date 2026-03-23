import Foundation

enum RecordingMode: String, Codable, CaseIterable {
    case toggle
    case pushToTalk = "push-to-talk"
}

enum TypingSpeed: String, Codable, CaseIterable {
    case instant
    case fast
    case natural

    var delayMs: Int {
        switch self {
        case .instant: return 0
        case .fast: return 10
        case .natural: return 50
        }
    }
}

enum TranscriptionLanguage: String, Codable, CaseIterable {
    case ja
    case en
    case auto
}

struct AppSettings: Codable, Equatable {
    var recordingMode: RecordingMode = .toggle
    var typingSpeed: TypingSpeed = .fast
    var language: TranscriptionLanguage = .ja
    var autoLaunch: Bool = false
    var showInMenuBar: Bool = true

    private static let userDefaultsKey = "io.dictate.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: AppSettings.userDefaultsKey)
        } catch {
            print("[AppSettings] Failed to save: \(error)")
        }
    }
}
