import SwiftUI
import KeyboardShortcuts
import Observation
import DictateCore
import os

/// Central application state coordinator.
/// Wires all services together and manages the recording lifecycle:
/// idle -> recording -> processing -> typing -> idle
@Observable
final class AppState {
    enum Status: String {
        case idle
        case recording
        case processing
        case typing
        case error
    }

    // MARK: - Published State
    var status: Status = .idle
    var errorMessage: String?
    var interimText: String = ""
    var lastTranscription: String = ""
    var audioLevels: [Float] = Array(repeating: 0, count: 24)

    // MARK: - Services (exposed for SettingsView)
    let keychainService = KeychainService()
    let dictionaryService = DictionaryService()
    let historyService = HistoryService()

    // MARK: - Internal Services
    private let audioRecorder = AudioRecorderService()
    private var deepgramService: DeepgramService?
    private let overlayController = OverlayPanelController()
    private let textInputService = TextInputService()
    private let logger = Logger(subsystem: "io.dictate.app", category: "AppState")

    // MARK: - State
    private var previousFrontApp: String?
    private var hasInitialized = false

    // MARK: - Computed
    var menuBarIconName: String {
        switch status {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .typing: return "keyboard"
        case .error: return "exclamationmark.triangle"
        }
    }

    var isRecording: Bool { status == .recording }
    var isProcessing: Bool { status == .processing }
    var isTyping: Bool { status == .typing }

    // MARK: - Initialization

    func initialize() {
        guard !hasInitialized else { return }
        hasInitialized = true

        do {
            try performInitialization()
        } catch {
            logger.error("[AppState] initialize failed: \(error.localizedDescription)")
        }
    }

    private func performInitialization() throws {
        // Run Electron -> Native data migration
        MigrationService.migrateIfNeeded()

        // Initialize Gemini if API key exists in Keychain
        if let apiKey = try? keychainService.retrieve(key: KeychainService.geminiKeyName) {
            GeminiServiceManager.initialize(apiKey: apiKey)
        }

        // Register global keyboard shortcuts
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.toggleRecording()
        }
        KeyboardShortcuts.onKeyUp(for: .cancelRecording) { [weak self] in
            self?.cancelRecording()
        }
        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        // Wire audio recorder callbacks
        audioRecorder.onAudioChunk = { [weak self] chunk in
            self?.deepgramService?.sendAudio(chunk)
        }

        // Observe audio levels from recorder via Combine
        setupAudioLevelObservation()

        logger.info("[AppState] Initialized successfully")
    }

    private func setupAudioLevelObservation() {
        // Poll audioRecorder.audioLevels via a timer while recording
        // AudioRecorderService publishes levels on main thread, we mirror them here
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.status == .recording else { return }
            self.audioLevels = self.audioRecorder.audioLevels
        }
    }

    // MARK: - Recording Lifecycle

    func toggleRecording() {
        switch status {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        default:
            break // Ignore during processing/typing
        }
    }

    func startRecording() {
        guard status == .idle else { return }

        // Check Gemini API key
        guard GeminiServiceManager.isInitialized else {
            errorMessage = "Gemini APIキーが設定されていません。設定画面でAPIキーを入力してください。"
            status = .error
            return
        }

        Task { @MainActor in
            do {
                try await performStartRecording()
            } catch {
                logger.error("[AppState] startRecording failed: \(error.localizedDescription)")
                errorMessage = "Recording start failed: \(error.localizedDescription)"
                status = .error
                overlayController.hideOverlay()
            }
        }
    }

    private func performStartRecording() async throws {
        // Remember frontmost app before showing overlay
        previousFrontApp = TextInputService.getFrontmostApp()

        // Show overlay
        let overlayView = OverlayView(
            appState: self,
            onCancel: { [weak self] in self?.cancelRecording() },
            onConfirm: { [weak self] in self?.stopRecording() }
        )
        overlayController.showOverlay(content: overlayView)

        // Start audio recording
        try audioRecorder.startRecording()

        // Start Deepgram streaming if key available
        startDeepgramIfAvailable()

        status = .recording
        interimText = ""
        errorMessage = nil

        logger.info("[AppState] Recording started")
    }

    func stopRecording() {
        guard status == .recording else { return }
        status = .processing

        Task { @MainActor in
            do {
                try await performStopRecording()
            } catch {
                logger.error("[AppState] stopRecording failed: \(error.localizedDescription)")
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                status = .idle
                overlayController.hideOverlay()
            }
        }
    }

    private func performStopRecording() async throws {
        // Stop Deepgram
        deepgramService?.close()
        deepgramService = nil

        // Stop recording and get audio data
        let audioData = try await audioRecorder.stopRecording()

        guard !audioData.isEmpty else {
            logger.warning("[AppState] Empty audio data")
            status = .idle
            overlayController.hideOverlay()
            return
        }

        // Transcribe with Gemini
        let gemini = GeminiServiceManager.shared
        let dictionaryPrompt = dictionaryService.getDictionaryPrompt()
        let text = try await gemini.transcribeAudio(
            audioData: audioData,
            mimeType: "audio/wav",
            dictionaryPrompt: dictionaryPrompt
        )

        guard !text.isEmpty else {
            logger.info("[AppState] No speech detected")
            status = .idle
            overlayController.hideOverlay()
            return
        }

        // Process text (remove unnecessary spaces in Japanese)
        let processedText = TextProcessing.removeJapaneseSpaces(text)

        // Save to history
        historyService.add(originalText: text, formattedText: processedText)

        // Type text into the previous app
        status = .typing
        let settings = AppSettings.load()
        try await textInputService.typeText(
            processedText,
            speed: settings.typingSpeed,
            targetApp: previousFrontApp
        )

        lastTranscription = processedText
        status = .idle

        // Hide overlay after a brief delay
        try? await Task.sleep(for: .milliseconds(100))
        overlayController.hideOverlay()

        logger.info("[AppState] Transcription complete: \(processedText.prefix(50))...")
    }

    func cancelRecording() {
        guard status == .recording else { return }

        audioRecorder.cancelRecording()
        deepgramService?.close()
        deepgramService = nil

        status = .idle
        interimText = ""
        overlayController.hideOverlay()

        logger.info("[AppState] Recording cancelled")
    }

    // MARK: - Deepgram Streaming

    private func startDeepgramIfAvailable() {
        guard let apiKey = try? keychainService.retrieve(key: KeychainService.deepgramKeyName) else { return }

        let settings = AppSettings.load()
        let language = settings.language.rawValue

        let service = DeepgramService()
        service.onTranscript = { [weak self] transcript in
            DispatchQueue.main.async {
                guard let self else { return }
                if transcript.isFinal {
                    if !self.interimText.isEmpty {
                        self.interimText += " "
                    }
                    self.interimText += transcript.text
                } else {
                    // Show interim (latest partial result)
                    self.interimText = transcript.text
                }
            }
        }
        service.onError = { [weak self] error in
            self?.logger.error("[AppState] Deepgram error: \(error.localizedDescription)")
        }

        service.connect(apiKey: apiKey, language: language)
        deepgramService = service
    }
}
