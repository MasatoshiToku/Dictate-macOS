import Foundation
import os

/// API key storage using UserDefaults.
/// Replaces Keychain to avoid password prompts with ad-hoc signed apps.
public final class KeychainService: Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "KeychainService")
    public let serviceName: String
    private let defaults: UserDefaults

    public static let geminiKeyName = "gemini-api-key"
    public static let deepgramKeyName = "deepgram-api-key"

    public init(serviceName: String = "io.dictate.app") {
        self.serviceName = serviceName
        self.defaults = UserDefaults.standard
    }

    private func defaultsKey(for key: String) -> String {
        "\(serviceName).\(key)"
    }

    public func save(key: String, value: String) throws {
        guard value.data(using: .utf8) != nil else {
            throw KeychainError.encodingFailed
        }
        defaults.set(value, forKey: defaultsKey(for: key))
    }

    public func retrieve(key: String) throws -> String {
        guard let value = defaults.string(forKey: defaultsKey(for: key)) else {
            throw KeychainError.notFound
        }
        return value
    }

    public func has(key: String) -> Bool {
        defaults.string(forKey: defaultsKey(for: key)) != nil
    }

    public func delete(key: String) throws {
        defaults.removeObject(forKey: defaultsKey(for: key))
    }

    public func getMaskedValue(key: String) -> String? {
        guard let value = try? retrieve(key: key) else { return nil }
        return Self.maskApiKey(value)
    }

    public static func maskApiKey(_ apiKey: String) -> String {
        if apiKey.count <= 8 {
            return String(repeating: "\u{25CF}", count: apiKey.count)
        }
        let prefix = apiKey.prefix(4)
        let suffix = apiKey.suffix(4)
        let masked = String(repeating: "\u{25CF}", count: apiKey.count - 8)
        return "\(prefix)\(masked)\(suffix)"
    }

    public enum KeychainError: Error, LocalizedError {
        case encodingFailed
        case saveFailed(status: OSStatus)
        case notFound
        case deleteFailed(status: OSStatus)

        public var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode value"
            case .saveFailed(let status): return "Save failed (OSStatus: \(status))"
            case .notFound: return "Key not found"
            case .deleteFailed(let status): return "Delete failed (OSStatus: \(status))"
            }
        }
    }
}
