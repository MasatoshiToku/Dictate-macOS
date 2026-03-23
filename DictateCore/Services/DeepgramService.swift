import Foundation
import os

public final class DeepgramService: @unchecked Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "DeepgramService")

    public struct Transcript {
        public let text: String
        public let isFinal: Bool

        public init(text: String, isFinal: Bool) {
            self.text = text
            self.isFinal = isFinal
        }
    }

    public var onTranscript: ((Transcript) -> Void)?
    public var onError: ((Error) -> Void)?
    public var onClose: (() -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var keepAliveTimer: Timer?
    private var pendingChunks: [Data] = []
    private let lock = NSLock()
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
        lock.lock()
        close_internal()
        pendingChunks.removeAll()
        currentApiKey = apiKey
        currentLanguage = language
        shouldReconnect = true
        reconnectAttempts = 0
        lock.unlock()

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
            "sample_rate=48000",
            "channels=1",
        ].joined(separator: "&")

        let url = URL(string: "wss://api.deepgram.com/v1/listen?\(params)")!
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        logger.info("[DeepgramService] Connecting...")

        // Start receiving messages
        receiveMessage()

        // Flush pending chunks after short delay for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.flushPendingChunks()
            self?.startKeepAlive()
        }

        lock.lock()
        isConnected = true
        lock.unlock()
    }

    public func sendAudio(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        guard let task = webSocketTask else { return }

        if task.state == .running {
            task.send(.data(data)) { [weak self] error in
                if let error {
                    self?.logger.error("[DeepgramService] send error: \(error.localizedDescription)")
                }
            }
        } else {
            // Buffer while connecting
            pendingChunks.append(data)
        }
    }

    public func close() {
        lock.lock()
        shouldReconnect = false
        reconnectAttempts = 0
        close_internal()
        lock.unlock()
    }

    private func close_internal() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil

        if let task = webSocketTask {
            // Send CloseStream for graceful shutdown
            let closeMessage = try? JSONSerialization.data(withJSONObject: ["type": "CloseStream"])
            if let closeMessage {
                task.send(.string(String(data: closeMessage, encoding: .utf8)!)) { _ in }
            }
            task.cancel(with: .normalClosure, reason: nil)
        }
        webSocketTask = nil
        isConnected = false
    }

    public func getIsConnected() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isConnected
    }

    // MARK: - Reconnection

    private func attemptReconnect() {
        lock.lock()
        guard shouldReconnect,
              reconnectAttempts < Self.maxReconnectAttempts,
              let apiKey = currentApiKey,
              let language = currentLanguage else {
            lock.unlock()
            logger.warning("[DeepgramService] Reconnect skipped: shouldReconnect=\(self.shouldReconnect), attempts=\(self.reconnectAttempts)")
            return
        }
        let attempt = reconnectAttempts
        reconnectAttempts += 1
        lock.unlock()

        let delay = Self.reconnectDelays[safe: attempt] ?? 2.0
        logger.info("[DeepgramService] Reconnecting in \(delay)s (attempt \(attempt + 1)/\(Self.maxReconnectAttempts))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            guard self.shouldReconnect else {
                self.lock.unlock()
                return
            }
            self.lock.unlock()
            self.performConnect(apiKey: apiKey, language: language)
        }
    }

    // MARK: - Private

    private func flushPendingChunks() {
        lock.lock()
        let chunks = pendingChunks
        pendingChunks.removeAll()
        lock.unlock()

        for chunk in chunks {
            sendAudio(chunk)
        }
        if !chunks.isEmpty {
            logger.info("[DeepgramService] Flushed \(chunks.count) pending chunks")
        }
    }

    private func startKeepAlive() {
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self, let task = self.webSocketTask, task.state == .running else { return }
            let keepAlive = "{\"type\":\"KeepAlive\"}"
            task.send(.string(keepAlive)) { _ in }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                self.logger.error("[DeepgramService] receive error: \(error.localizedDescription)")
                self.lock.lock()
                self.isConnected = false
                self.lock.unlock()
                self.onError?(error)

                // Attempt reconnection if still recording
                self.attemptReconnect()
            }
        }
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
        var request = URLRequest(url: URL(string: "https://api.deepgram.com/v1/projects")!)
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
