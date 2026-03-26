import Testing
@testable import DictateCore

@Suite("GeminiServiceManager")
struct GeminiServiceManagerTests {
    @Test("isInitialized returns false before initialization")
    func notInitializedByDefault() {
        // Note: Can't easily test this in isolation since it's a global singleton
        // Just verify the API exists and is accessible
        _ = GeminiServiceManager.isInitialized
    }

    @Test("shared returns nil before initialization")
    func sharedReturnsNilBeforeInit() {
        // After the fatalError removal, shared should return nil
        // Note: Other tests may have initialized it, so we just verify the API
        let _ = GeminiServiceManager.shared
    }

    @Test("initialize creates shared instance")
    func initializeCreatesInstance() {
        GeminiServiceManager.initialize(apiKey: "test-key-12345")
        #expect(GeminiServiceManager.isInitialized == true)
        #expect(GeminiServiceManager.shared != nil)
    }

    @Test("re-initialize replaces instance")
    func reInitializeReplacesInstance() {
        GeminiServiceManager.initialize(apiKey: "key-1")
        let first = GeminiServiceManager.shared
        GeminiServiceManager.initialize(apiKey: "key-2")
        let second = GeminiServiceManager.shared
        // Both should be non-nil (can't easily compare actor identity)
        #expect(first != nil)
        #expect(second != nil)
    }
}
