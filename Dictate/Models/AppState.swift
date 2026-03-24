import SwiftUI
import KeyboardShortcuts
import Observation
import DictateCore
import ServiceManagement
import AVFoundation
import ApplicationServices
import os

/// Notification posted when recording mode changes in settings.
extension Notification.Name {
    static let recordingModeChanged = Notification.Name("io.dictate.recordingModeChanged")
}

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
    let updaterService = UpdaterService()

    // MARK: - Internal Services
    private let audioRecorder = AudioRecorderService()
    private var deepgramService: DeepgramService?
    private let overlayController = OverlayPanelController()
    private let textInputService = TextInputService()
    private let logger = Logger(subsystem: "io.dictate.app", category: "AppState")

    // MARK: - State
    private var previousFrontApp: String?
    private var hasInitialized = false
    private var audioLevelTimer: Timer?
    private var recordingTimeoutTimer: Timer?
    private static let maxRecordingDuration: TimeInterval = 120

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
        // Check accessibility permission on first launch
        checkAccessibilityPermission()

        // Run Electron -> Native data migration
        MigrationService.migrateIfNeeded()

        // Initialize Gemini if API key exists in Keychain
        if let apiKey = try? keychainService.retrieve(key: KeychainService.geminiKeyName) {
            GeminiServiceManager.initialize(apiKey: apiKey)
        }

        // Sync login item state with settings
        let settings = AppSettings.load()
        if settings.autoLaunch {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }

        // Register global keyboard shortcuts based on current recording mode
        registerShortcuts()

        // Re-register shortcuts when recording mode changes
        NotificationCenter.default.addObserver(
            forName: .recordingModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerShortcuts()
        }

        // Wire audio recorder callbacks
        audioRecorder.onAudioChunk = { [weak self] chunk in
            self?.deepgramService?.sendAudio(chunk)
        }

        // Observe audio levels from recorder via Combine
        setupAudioLevelObservation()

        logger.info("[AppState] Initialized successfully")
    }

    // MARK: - Shortcut Registration

    /// Registers keyboard shortcuts based on the current recording mode.
    /// Push-to-talk: hold key to record, release to stop.
    /// Toggle: press once to start, press again to stop.
    private func registerShortcuts() {
        KeyboardShortcuts.removeAllHandlers()

        let settings = AppSettings.load()

        if settings.recordingMode == .pushToTalk {
            // Push-to-talk: hold to record, release to stop
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                guard self?.status == .idle else { return }
                self?.startRecording()
            }
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                guard self?.status == .recording else { return }
                self?.stopRecording()
            }
        } else {
            // Toggle mode: press to start, press again to stop
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                self?.toggleRecording()
            }
        }

        // Cancel is always key-up
        KeyboardShortcuts.onKeyUp(for: .cancelRecording) { [weak self] in
            self?.cancelRecording()
        }

        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func setupAudioLevelObservation() {
        audioLevelTimer?.invalidate()
        // Poll audioRecorder.audioLevels via a timer while recording
        // AudioRecorderService publishes levels on main thread, we mirror them here
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.status == .recording else { return }
            self.audioLevels = self.audioRecorder.audioLevels
        }
    }

    private func stopAudioLevelObservation() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    // MARK: - Recording Lifecycle

    func toggleRecording() {
        switch status {
        case .idle, .error:
            if status == .error {
                errorMessage = nil
                status = .idle
            }
            startRecording()
        case .recording:
            stopRecording()
        default:
            break // Ignore during processing/typing
        }
    }

    func startRecording() {
        // Concurrent recording guard: only start from idle
        guard status == .idle else {
            logger.warning("[AppState] startRecording ignored: status=\(self.status.rawValue)")
            return
        }

        // Check Gemini API key
        guard GeminiServiceManager.isInitialized else {
            errorMessage = "Gemini APIキーが設定されていません。設定画面でAPIキーを入力してください。"
            status = .error
            return
        }

        // Immediately transition to prevent double-trigger from rapid key presses
        status = .recording

        Task { @MainActor in
            do {
                try await performStartRecording()
            } catch {
                logger.error("[AppState] startRecording failed: \(error.localizedDescription)")
                errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
                status = .error
                overlayController.hideOverlay()
            }
        }
    }

    private func performStartRecording() async throws {
        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break // OK
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                errorMessage = "マイクへのアクセスが拒否されました"
                status = .error
                return
            }
        case .denied, .restricted:
            errorMessage = "マイクの使用が拒否されています。システム設定 > プライバシーとセキュリティ > マイク で許可してください。"
            status = .error
            return
        @unknown default:
            break
        }

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

        // status is already .recording (set in startRecording() to prevent double-trigger)
        interimText = ""
        errorMessage = nil

        // Schedule recording timeout (auto-stop after 120 seconds)
        recordingTimeoutTimer?.invalidate()
        recordingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.maxRecordingDuration, repeats: false) { [weak self] _ in
            guard let self, self.status == .recording else { return }
            self.interimText += self.interimText.isEmpty ? "（録音時間上限に達しました）" : "\n（録音時間上限に達しました）"
            self.logger.info("[AppState] Recording timeout reached (\(Self.maxRecordingDuration)s)")
            self.stopRecording()
        }

        logger.info("[AppState] Recording started")
    }

    func stopRecording() {
        guard status == .recording else { return }
        recordingTimeoutTimer?.invalidate()
        recordingTimeoutTimer = nil
        status = .processing

        Task { @MainActor in
            do {
                try await performStopRecording()
            } catch {
                logger.error("[AppState] stopRecording failed: \(error.localizedDescription)")
                errorMessage = "文字起こしに失敗しました: \(error.localizedDescription)"
                status = .idle
                overlayController.hideOverlay()
            }
        }
    }

    private func performStopRecording() async throws {
        // Stop Deepgram
        deepgramService?.close()
        deepgramService = nil
        stopAudioLevelObservation()

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

        // Play completion sound
        NSSound(named: .init("Pop"))?.play()

        // Hide overlay after a brief delay
        try? await Task.sleep(for: .milliseconds(100))
        overlayController.hideOverlay()

        logger.info("[AppState] Transcription complete: \(processedText.prefix(50))...")
    }

    func cancelRecording() {
        guard status == .recording else { return }

        recordingTimeoutTimer?.invalidate()
        recordingTimeoutTimer = nil
        audioRecorder.cancelRecording()
        deepgramService?.close()
        deepgramService = nil
        stopAudioLevelObservation()

        status = .idle
        interimText = ""
        overlayController.hideOverlay()

        logger.info("[AppState] Recording cancelled")
    }

    // MARK: - Permissions

    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            logger.warning("[AppState] Accessibility permission not granted")
        }
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
