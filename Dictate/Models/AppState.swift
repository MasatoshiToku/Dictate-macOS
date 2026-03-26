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
    var confirmedInterimText: String = "" // Internal: used by AppState extensions only
    var lastTranscription: String = ""
    var audioLevels: [Float] = Array(repeating: 0, count: 36)

    // MARK: - Services (exposed for SettingsView)
    let keychainService = KeychainService()
    let dictionaryService = DictionaryService()
    let historyService = HistoryService()
    let updaterService = UpdaterService()

    // MARK: - Internal Services
    let audioRecorder = AudioRecorderService() // Internal: used by AppState extensions only
    var deepgramService: DeepgramService? // Internal: used by AppState extensions only
    var transcriptionService: (any TranscriptionService)? // Internal: used by AppState extensions only
    let overlayController = OverlayPanelController() // Internal: used by AppState extensions only
    let textInputService = TextInputService() // Internal: used by AppState extensions only
    let logger = Logger(subsystem: "io.dictate.app", category: "AppState") // Internal: used by AppState extensions only

    // MARK: - State
    var previousFrontApp: String? // Internal: used by AppState extensions only
    private var hasInitialized = false
    var audioLevelTimer: DispatchSourceTimer? // Internal: used by AppState extensions only
    var recordingTimeoutTimer: DispatchSourceTimer? // Internal: used by AppState extensions only
    static let maxRecordingDuration: TimeInterval = 120 // Internal: used by AppState extensions only

    // Escape key monitors (active only during recording)
    var escapeMonitors: [Any] = [] // Internal: used by AppState extensions only

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
            errorMessage = "初期化に失敗しました: \(error.localizedDescription)"
            status = .error
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
            transcriptionService = GeminiServiceManager.shared
        }

        // Sync login item state with settings
        let settings = AppSettings.load()
        if settings.autoLaunch {
            do { try SMAppService.mainApp.register() }
            catch { logger.warning("[AppState] Auto-launch register failed: \(error.localizedDescription)") }
        } else {
            do { try SMAppService.mainApp.unregister() }
            catch { logger.warning("[AppState] Auto-launch unregister failed: \(error.localizedDescription)") }
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
                guard self?.status == .idle else {
                    return
                }
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

        // Cancel shortcut: only register if user has set a custom (non-escape) shortcut.
        // Escape key is handled separately via NSEvent monitors (only active during recording).
        if let shortcut = KeyboardShortcuts.getShortcut(for: .cancelRecording),
           shortcut.key != .escape || !shortcut.modifiers.isEmpty {
            KeyboardShortcuts.onKeyUp(for: .cancelRecording) { [weak self] in
                self?.cancelRecording()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            AppDelegate.shared?.openSettings()
        }

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
        guard transcriptionService != nil else {
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
                stopEscapeMonitoring()
                overlayController.hideOverlay()
            }
        }
    }

    func stopRecording() {
        guard status == .recording else {
            return
        }
        recordingTimeoutTimer?.cancel()
        recordingTimeoutTimer = nil
        status = .processing
        stopEscapeMonitoring()

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

    func cancelRecording() {
        guard status == .recording else { return }

        recordingTimeoutTimer?.cancel()
        recordingTimeoutTimer = nil
        stopEscapeMonitoring()
        audioRecorder.cancelRecording()
        deepgramService?.close()
        deepgramService = nil
        stopAudioLevelObservation()

        status = .idle
        interimText = ""
        confirmedInterimText = ""
        overlayController.hideOverlay()

        logger.info("[AppState] Recording cancelled")
    }

}
