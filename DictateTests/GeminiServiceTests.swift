import Testing
import Foundation
@testable import DictateCore

// Mock URLProtocol for testing
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// Serialize to avoid shared static handler conflicts
@Suite("GeminiService", .serialized)
struct GeminiServiceTests {

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }

    private func makeGeminiResponse(text: String) -> Data {
        let json: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": text]
                        ]
                    ]
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test("NO_SPEECH marker returns empty string")
    func noSpeechMarker() async throws {
        let noSpeechResponse = makeGeminiResponse(text: "[NO_SPEECH]")
        MockURLProtocol.requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, noSpeechResponse)
        }

        let service = GeminiService(apiKey: "test-key", session: makeMockSession())
        let result = try await service.transcribeAudio(
            audioData: Data([0x00, 0x01]),
            mimeType: "audio/wav",
            dictionaryPrompt: ""
        )
        #expect(result.isEmpty, "Expected empty string for [NO_SPEECH] response")
    }

    @Test("Successful transcription returns text")
    func successfulTranscription() async throws {
        let expectedText = "Hello world"
        let successResponse = makeGeminiResponse(text: expectedText)
        MockURLProtocol.requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, successResponse)
        }

        let service = GeminiService(apiKey: "test-key", session: makeMockSession())
        let result = try await service.transcribeAudio(
            audioData: Data([0x00, 0x01]),
            mimeType: "audio/wav",
            dictionaryPrompt: ""
        )
        #expect(result == expectedText, "Expected '\(expectedText)' but got '\(result)'")
    }

    @Test("Circuit breaker opens after consecutive failures")
    func circuitBreakerOpens() async {
        MockURLProtocol.requestCount = 0
        // Use 401 (non-retryable) to avoid retry delays
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = GeminiService(apiKey: "test-key", session: makeMockSession())

        // Trigger 5 consecutive failures (threshold is 5)
        // recordFailure() is called once per transcribeAudio() call
        // Use 401 (non-retryable) so each call fails immediately without retries
        for _ in 0..<5 {
            do {
                _ = try await service.transcribeAudio(
                    audioData: Data([0x00]),
                    mimeType: "audio/wav",
                    dictionaryPrompt: ""
                )
            } catch {
                // Expected unauthorized error
            }
        }

        // Next call should fail with circuit breaker open
        do {
            _ = try await service.transcribeAudio(
                audioData: Data([0x00]),
                mimeType: "audio/wav",
                dictionaryPrompt: ""
            )
            Issue.record("Expected circuitBreakerOpen error")
        } catch let error as GeminiError {
            switch error {
            case .circuitBreakerOpen:
                break // Expected
            default:
                Issue.record("Expected circuitBreakerOpen but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Non-retryable error does not retry")
    func nonRetryableError() async {
        MockURLProtocol.requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = GeminiService(apiKey: "test-key", session: makeMockSession())
        do {
            _ = try await service.transcribeAudio(
                audioData: Data([0x00]),
                mimeType: "audio/wav",
                dictionaryPrompt: ""
            )
            Issue.record("Expected unauthorized error")
        } catch let error as GeminiError {
            switch error {
            case .unauthorized:
                break // Expected
            default:
                Issue.record("Expected unauthorized but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        // Should only have made 1 request (no retries for 401)
        #expect(MockURLProtocol.requestCount == 1, "Expected 1 request for non-retryable error, got \(MockURLProtocol.requestCount)")
    }

    @Test("Invalid API key throws error")
    func invalidApiKey() async {
        MockURLProtocol.requestCount = 0
        let service = GeminiService(apiKey: "", session: makeMockSession())
        do {
            _ = try await service.transcribeAudio(
                audioData: Data([0x00]),
                mimeType: "audio/wav",
                dictionaryPrompt: ""
            )
            Issue.record("Expected invalidAPIKey error")
        } catch let error as GeminiError {
            switch error {
            case .invalidAPIKey:
                break // Expected
            default:
                Issue.record("Expected invalidAPIKey but got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("GeminiError descriptions are non-empty")
    func errorDescriptions() {
        let errors: [GeminiError] = [
            .invalidAPIKey,
            .badRequest("test"),
            .unauthorized,
            .rateLimited,
            .serverError(500),
            .circuitBreakerOpen,
            .invalidResponse,
            .noTranscription,
            .networkError(NSError(domain: "test", code: -1)),
        ]
        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have a description")
            #expect(!error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    @Test("Rate limited error is retryable and recovers")
    func rateLimitedRetries() async {
        MockURLProtocol.requestCount = 0
        var callCount = 0
        let successResponse = makeGeminiResponse(text: "recovered")

        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount <= 2 {
                let response = HTTPURLResponse(
                    url: URL(string: "https://example.com")!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, successResponse)
        }

        let service = GeminiService(apiKey: "test-key", session: makeMockSession())
        do {
            let result = try await service.transcribeAudio(
                audioData: Data([0x00]),
                mimeType: "audio/wav",
                dictionaryPrompt: ""
            )
            #expect(result == "recovered")
            #expect(callCount == 3, "Expected 3 calls (2 retries + 1 success)")
        } catch {
            Issue.record("Should have recovered after retries: \(error)")
        }
    }
}
