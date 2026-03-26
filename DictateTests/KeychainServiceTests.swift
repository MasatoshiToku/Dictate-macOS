import Testing
import Foundation
@testable import DictateCore

@Suite("KeychainService")
struct KeychainServiceTests {
    private let testService = "io.dictate.app.test.\(UUID().uuidString)"

    @Test("Save and retrieve API key")
    func saveAndRetrieve() throws {
        let service = KeychainService(serviceName: testService)
        try service.save(key: "gemini-api-key", value: "test-api-key-12345")
        let retrieved = try service.retrieve(key: "gemini-api-key")
        #expect(retrieved == "test-api-key-12345")
        // Cleanup
        try? service.delete(key: "gemini-api-key")
    }

    @Test("Delete API key")
    func deleteKey() throws {
        let service = KeychainService(serviceName: testService)
        try service.save(key: "gemini-api-key", value: "test-api-key-12345")
        try service.delete(key: "gemini-api-key")
        let retrieved = try? service.retrieve(key: "gemini-api-key")
        #expect(retrieved == nil)
    }

    @Test("Has key check")
    func hasKey() throws {
        let service = KeychainService(serviceName: testService)
        #expect(service.has(key: "gemini-api-key") == false)
        try service.save(key: "gemini-api-key", value: "test-api-key-12345")
        #expect(service.has(key: "gemini-api-key") == true)
        try? service.delete(key: "gemini-api-key")
    }

    @Test("Mask API key string")
    func maskApiKey() {
        // "AIzaSyABC123456789XYZ" = 21 chars -> prefix(4) + 13 masked + suffix(4)
        let masked21 = "AIza" + String(repeating: "\u{25CF}", count: 13) + "9XYZ"
        #expect(KeychainService.maskApiKey("AIzaSyABC123456789XYZ") == masked21)
        // "short" = 5 chars <= 8 -> all masked
        #expect(KeychainService.maskApiKey("short") == String(repeating: "\u{25CF}", count: 5))
        // "12345678" = 8 chars <= 8 -> all masked
        #expect(KeychainService.maskApiKey("12345678") == String(repeating: "\u{25CF}", count: 8))
        // "123456789" = 9 chars -> prefix(4) + 1 masked + suffix(4)
        #expect(KeychainService.maskApiKey("123456789") == "1234\u{25CF}6789")
    }

    @Test("getMaskedValue returns nil for missing key")
    func getMaskedValueMissing() {
        // Use unique service name to avoid collision
        let service = KeychainService(serviceName: "test-\(UUID())")
        #expect(service.getMaskedValue(key: "nonexistent") == nil)
    }

    @Test("getMaskedValue returns masked value for existing key")
    func getMaskedValueExists() throws {
        let service = KeychainService(serviceName: "test-\(UUID())")
        try service.save(key: "api-key", value: "sk-1234567890abcdef")
        let masked = service.getMaskedValue(key: "api-key")
        #expect(masked != nil)
        #expect(masked?.hasPrefix("sk-1") == true)
        #expect(masked?.hasSuffix("cdef") == true)
        #expect(masked?.contains("\u{25CF}") == true)
        // Cleanup
        try? service.delete(key: "api-key")
    }
}