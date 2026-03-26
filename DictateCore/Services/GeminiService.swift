import Foundation
import os

// MARK: - GeminiService Errors

public enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case badRequest(String)
    case unauthorized
    case rateLimited
    case serverError(Int)
    case circuitBreakerOpen
    case invalidResponse
    case noTranscription
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Invalid or missing Gemini API key"
        case .badRequest(let detail): return "Bad request: \(detail)"
        case .unauthorized: return "Unauthorized: check your API key"
        case .rateLimited: return "Rate limited: too many requests"
        case .serverError(let code): return "Server error (HTTP \(code))"
        case .circuitBreakerOpen: return "Service temporarily unavailable (circuit breaker open)"
        case .invalidResponse: return "Invalid response from Gemini API"
        case .noTranscription: return "No transcription result"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - GeminiService

public actor GeminiService: TranscriptionService {
    private let logger = Logger(subsystem: "io.dictate.app", category: "GeminiService")
    private let apiKey: String
    private let session: URLSession
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    // Retry configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0

    // Circuit breaker
    private var consecutiveFailures = 0
    private let circuitBreakerThreshold = 5
    private let circuitBreakerCooldown: TimeInterval = 60.0
    private var circuitOpenedAt: Date?

    // [NO_SPEECH] marker
    private static let noSpeechMarker = "[NO_SPEECH]"

    // System prompt for Japanese transcription (ported from Electron version)
    private static let systemPrompt = """
    あなたは音声文字起こしアシスタントです。与えられた音声データを正確にテキストに変換してください。

    ルール:
    1. フィラー（えっと、あー、うーん、えー、あのー、そのー、まあ、なんか 等）は除去してください
    2. 文法を自然に修正してください
    3. 適切な句読点（。、！？）を付けてください
    4. 音声が検出されない場合は [NO_SPEECH] とだけ返してください
    5. 文字起こし結果のテキストのみを返してください。説明や注釈は不要です
    6. 音声の言語で文字起こししてください
    """

    public init(apiKey: String, session: URLSession? = nil) {
        self.apiKey = apiKey
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API

    /// Transcribe audio with retries and circuit breaker protection
    public func transcribeAudio(audioData: Data, mimeType: String, dictionaryPrompt: String) async throws -> String {
        try checkCircuitBreaker()

        var lastError: Error = GeminiError.noTranscription

        for attempt in 0..<maxRetries {
            do {
                let result = try await performTranscription(
                    audioData: audioData,
                    mimeType: mimeType,
                    dictionaryPrompt: dictionaryPrompt,
                    timeout: 30
                )
                recordSuccess()
                return result
            } catch {
                lastError = error
                logger.warning("[GeminiService] transcribeAudio attempt \(attempt + 1)/\(self.maxRetries) failed: \(error.localizedDescription)")

                // Don't retry on non-retryable errors
                if !isRetryable(error) {
                    recordFailure()
                    throw error
                }

                // Linear backoff: 1s, 2s, 3s
                if attempt < maxRetries - 1 {
                    let delay = baseRetryDelay * Double(attempt + 1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        recordFailure()
        throw lastError
    }

    /// Best-effort interim transcription: 8s timeout, no retries
    public func transcribeInterim(audioData: Data, mimeType: String, dictionaryPrompt: String) async -> String {
        do {
            try checkCircuitBreaker()
            let result = try await performTranscription(
                audioData: audioData,
                mimeType: mimeType,
                dictionaryPrompt: dictionaryPrompt,
                timeout: 8
            )
            recordSuccess()
            return result
        } catch {
            logger.info("[GeminiService] transcribeInterim failed (best-effort): \(error.localizedDescription)")
            return ""
        }
    }

    // MARK: - Core Request

    private func performTranscription(
        audioData: Data,
        mimeType: String,
        dictionaryPrompt: String,
        timeout: TimeInterval
    ) async throws -> String {
        let url = try buildURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = timeout

        let body = buildRequestBody(audioData: audioData, mimeType: mimeType, dictionaryPrompt: dictionaryPrompt)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        try handleHTTPStatus(httpResponse.statusCode, data: data)

        return try parseResponse(data)
    }

    private func buildURL() throws -> URL {
        guard !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidAPIKey
        }
        return url
    }

    private func buildRequestBody(audioData: Data, mimeType: String, dictionaryPrompt: String) -> [String: Any] {
        let base64Audio = audioData.base64EncodedString()

        var userParts: [[String: Any]] = []

        // Add dictionary prompt if provided
        if !dictionaryPrompt.isEmpty {
            userParts.append(["text": dictionaryPrompt])
        }

        // Add audio data
        userParts.append([
            "inline_data": [
                "mime_type": mimeType,
                "data": base64Audio,
            ]
        ])

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": Self.systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": userParts,
                ]
            ],
        ]

        return body
    }

    // MARK: - Response Handling

    private func handleHTTPStatus(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200:
            return
        case 400:
            let detail = extractErrorMessage(from: data)
            throw GeminiError.badRequest(detail)
        case 401, 403:
            throw GeminiError.unauthorized
        case 429:
            throw GeminiError.rateLimited
        case 500...599:
            throw GeminiError.serverError(statusCode)
        default:
            throw GeminiError.serverError(statusCode)
        }
    }

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // [NO_SPEECH] detection -> return empty string
        if trimmed == Self.noSpeechMarker || trimmed.contains(Self.noSpeechMarker) {
            return ""
        }

        if trimmed.isEmpty {
            return ""
        }

        return trimmed
    }

    private func extractErrorMessage(from data: Data) -> String {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
        } catch {
            // Fall through
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    // MARK: - Circuit Breaker

    private func checkCircuitBreaker() throws {
        guard let openedAt = circuitOpenedAt else { return }

        let elapsed = Date().timeIntervalSince(openedAt)
        if elapsed < circuitBreakerCooldown {
            logger.warning("[GeminiService] Circuit breaker open, \(Int(self.circuitBreakerCooldown - elapsed))s remaining")
            throw GeminiError.circuitBreakerOpen
        }

        // Cooldown elapsed, reset circuit breaker
        logger.info("[GeminiService] Circuit breaker cooldown elapsed, resetting")
        circuitOpenedAt = nil
        consecutiveFailures = 0
    }

    private func recordSuccess() {
        consecutiveFailures = 0
        circuitOpenedAt = nil
    }

    private func recordFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= circuitBreakerThreshold {
            circuitOpenedAt = Date()
            logger.error("[GeminiService] Circuit breaker opened after \(self.consecutiveFailures) consecutive failures")
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        guard let geminiError = error as? GeminiError else {
            return true // Network errors are retryable
        }
        switch geminiError {
        case .rateLimited, .serverError, .networkError:
            return true
        case .invalidAPIKey, .unauthorized, .badRequest, .circuitBreakerOpen, .invalidResponse, .noTranscription:
            return false
        }
    }
}
