import Foundation
import os

public actor DeepgramService {
    private let logger = Logger(subsystem: "io.dictate.app", category: "DeepgramService")

    public struct Transcript {
        public let text: String
        public let isFinal: Bool

        public init(text: String, isFinal: Bool) {
            self.text = text
            self.isFinal = isFinal
        }
    }

    nonisolated(unsafe) public var onTranscript: ((Transcript) -> Void)?
    nonisolated(unsafe) public var onError: ((Error) -> Void)?
    nonisolated(unsafe) public var onClose: (() -> Void)?

    private let session = URLSession(configuration: .default)
    private var webSocketTask: URLSessionWebSocketTask?
    private var keepAliveTimer: Timer?
    private var pendingChunks: [Data] = []
    private var isConnected = false

    // Reconnection state
    private var currentApiKey: String?
    private var currentLanguage: String?
    private var shouldReconnect = false
    private var reconnectAttempts = 0
    private static let maxReconnectAttempts = 3
    private static let reconnectDelays: [TimeInterval] = [0.5, 1.0, 2.0]

    public init() {}

    public func connect(apiKey: String, language: String = "ja") {
        teardownConnection()
        pendingChunks.removeAll()
        currentApiKey = apiKey
        currentLanguage = language
        shouldReconnect = true
        reconnectAttempts = 0

        performConnect(apiKey: apiKey, language: language)
    }

    private func performConnect(apiKey: String, language: String) {
        let params = [
            "model=nova-3",
            "language=\(language)",
            "interim_results=true",
            "punctuate=true",
            "smart_format=true",
            "encoding=linear16",
            "sample_rate=16000",
            "channels=1",
        ].joined(separator: "&")

        guard let url = URL(string: "wss://api.deepgram.com/v1/listen?\(params)") else {
            logger.error("[DeepgramService] Failed to construct WebSocket URL")
            onError?(NSError(domain: "DeepgramService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct WebSocket URL"]))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        webSocketTask = self.session.webSocketTask(with: request)
        webSocketTask?.resume()

        logger.info("[DeepgramService] Connecting...")

        // Start receiving messages
        receiveMessage()

        // Flush pending chunks after short delay for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            Task { await self.flushPendingChunks() }
            Task { await self.startKeepAlive() }
        }

        isConnected = true
    }

    public nonisolated func sendAudio(_ data: Data) {
        Task { await self.enqueueSendAudio(data) }
    }

    private func enqueueSendAudio(_ data: Data) {
        guard let task = webSocketTask else { return }

        if task.state == .running {
            task.send(.data(data)) { [weak self] error in
                if let error {
                    Task { await self?.handleSendError(error) }
                }
            }
        } else {
            // Buffer while connecting
            pendingChunks.append(data)
        }
    }

    private func handleSendError(_ error: Error) {
        logger.error("[DeepgramService] send error: \(error.localizedDescription)")
    }

    public nonisolated func close() {
        Task { await self.performClose() }
    }

    private func performClose() {
        shouldReconnect = false
        reconnectAttempts = 0
        teardownConnection()
    }

    private func teardownConnection() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil

        if let task = webSocketTask {
            // Send CloseStream for graceful shutdown
            let closeMessage = try? JSONSerialization.data(withJSONObject: ["type": "CloseStream"])
            if let closeMessage {
                if let closeString = String(data: closeMessage, encoding: .utf8) { task.send(.string(closeString)) { _ in } }
            }
            task.cancel(with: .normalClosure, reason: nil)
        }
        webSocketTask = nil
        isConnected = false
    }

    public var connectedStatus: Bool {
        isConnected
    }

    // MARK: - Reconnection

    private func attemptReconnect() {
        guard shouldReconnect,
              reconnectAttempts < Self.maxReconnectAttempts,
              let apiKey = currentApiKey,
              let language = currentLanguage else {
            let attempts = reconnectAttempts
            let shouldRC = shouldReconnect
            logger.warning("[DeepgramService] Reconnect skipped: shouldReconnect=\(shouldRC), attempts=\(attempts)")
            if attempts >= Self.maxReconnectAttempts {
                onError?(NSError(domain: "DeepgramService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Max reconnection attempts reached"]))
            }
            return
        }
        let attempt = reconnectAttempts
        reconnectAttempts += 1

        let delay = Self.reconnectDelays[safe: attempt] ?? 2.0
        logger.info("[DeepgramService] Reconnecting in \(delay)s (attempt \(attempt + 1)/\(Self.maxReconnectAttempts))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            Task {
                guard await self.shouldReconnect else { return }
                await self.performConnect(apiKey: apiKey, language: language)
            }
        }
    }

    // MARK: - Private

    private func flushPendingChunks() {
        let chunks = pendingChunks
        pendingChunks.removeAll()

        for chunk in chunks {
            enqueueSendAudio(chunk)
        }
        if !chunks.isEmpty {
            logger.info("[DeepgramService] Flushed \(chunks.count) pending chunks")
        }
    }

    private func startKeepAlive() {
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.sendKeepAlive()
            }
        }
    }

    private func sendKeepAlive() {
        guard let task = webSocketTask, task.state == .running else { return }
        let keepAlive = "{\"type\":\"KeepAlive\"}"
        task.send(.string(keepAlive)) { _ in }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { await self.handleMessage(text) }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { await self.handleMessage(text) }
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                Task { await self.receiveMessage() }

            case .failure(let error):
                Task {
                    await self.handleReceiveError(error)
                }
            }
        }
    }

    private func handleReceiveError(_ error: Error) {
        logger.error("[DeepgramService] receive error: \(error.localizedDescription)")
        isConnected = false
        onError?(error)

        // Attempt reconnection if still recording
        attemptReconnect()
    }

    private func handleMessage(_ text: String) {
        do {
            guard let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            if type == "Results" {
                guard let channel = json["channel"] as? [String: Any],
                      let alternatives = channel["alternatives"] as? [[String: Any]],
                      let transcript = alternatives.first?["transcript"] as? String,
                      !transcript.isEmpty else { return }

                let isFinal = json["is_final"] as? Bool ?? false
                onTranscript?(Transcript(text: transcript, isFinal: isFinal))
            } else if type == "Error" {
                let message = json["message"] as? String ?? "Deepgram API error"
                onError?(NSError(domain: "DeepgramService", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
            }
        } catch {
            logger.error("[DeepgramService] parse error: \(error.localizedDescription)")
        }
    }

    // MARK: - API Key Validation

    public static func validateApiKey(_ apiKey: String) async throws -> Bool {
        guard let validationURL = URL(string: "https://api.deepgram.com/v1/projects") else { return false }
        var request = URLRequest(url: validationURL)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
