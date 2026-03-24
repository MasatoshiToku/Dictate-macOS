import Foundation
import os

public enum RecordingMode: String, Codable, CaseIterable, Sendable {
    case toggle
    case pushToTalk = "push-to-talk"
}

public enum TypingSpeed: String, Codable, CaseIterable, Sendable {
    case instant
    case fast
    case natural

    public var delayMs: Int {
        switch self {
        case .instant: return 0
        case .fast: return 10
        case .natural: return 50
        }
    }
}

public enum TranscriptionLanguage: String, Codable, CaseIterable, Sendable {
    case ja
    case en
    case auto
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var recordingMode: RecordingMode = .toggle
    public var typingSpeed: TypingSpeed = .fast
    public var language: TranscriptionLanguage = .ja
    public var autoLaunch: Bool = false
    public var showInMenuBar: Bool = true

    private static let userDefaultsKey = "io.dictate.settings"

    public init(
        recordingMode: RecordingMode = .toggle,
        typingSpeed: TypingSpeed = .fast,
        language: TranscriptionLanguage = .ja,
        autoLaunch: Bool = false,
        showInMenuBar: Bool = true
    ) {
        self.recordingMode = recordingMode
        self.typingSpeed = typingSpeed
        self.language = language
        self.autoLaunch = autoLaunch
        self.showInMenuBar = showInMenuBar
    }

    public static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: AppSettings.userDefaultsKey)
        } catch {
            os.Logger(subsystem: "io.dictate.app", category: "AppSettings").error("[AppSettings] save failed: \(error.localizedDescription)")
        }
    }
}
