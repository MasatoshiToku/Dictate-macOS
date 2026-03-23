import Foundation
import Security
import os

final class KeychainService: Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "KeychainService")
    let serviceName: String

    static let geminiKeyName = "gemini-api-key"
    static let deepgramKeyName = "deepgram-api-key"

    init(serviceName: String = "io.dictate.app") {
        self.serviceName = serviceName
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("[KeychainService] save failed: \(status)")
            throw KeychainError.saveFailed(status: status)
        }
    }

    func retrieve(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }

        return value
    }

    func has(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    func getMaskedValue(key: String) -> String? {
        guard let value = try? retrieve(key: key) else { return nil }
        return Self.maskApiKey(value)
    }

    static func maskApiKey(_ apiKey: String) -> String {
        if apiKey.count <= 8 {
            return String(repeating: "\u{25CF}", count: apiKey.count)
        }
        let prefix = apiKey.prefix(4)
        let suffix = apiKey.suffix(4)
        let masked = String(repeating: "\u{25CF}", count: apiKey.count - 8)
        return "\(prefix)\(masked)\(suffix)"
    }

    enum KeychainError: Error, LocalizedError {
        case encodingFailed
        case saveFailed(status: OSStatus)
        case notFound
        case deleteFailed(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode value"
            case .saveFailed(let status): return "Keychain save failed (OSStatus: \(status))"
            case .notFound: return "Key not found in Keychain"
            case .deleteFailed(let status): return "Keychain delete failed (OSStatus: \(status))"
            }
        }
    }
}
