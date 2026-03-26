import SwiftUI
import AVFoundation
import DictateCore
import os

// MARK: - Recording Lifecycle
// Internal: used by AppState extensions only

extension AppState {

    // Internal: used by AppState extensions only
    func performStartRecording() async throws {

        // Capture the user's working app BEFORE any permission dialogs or overlay.
        // This prevents capturing "Dictate" itself when mic/accessibility prompts steal focus.
        let capturedApp = TextInputService.getFrontmostApp()
        let selfBundleId = Bundle.main.bundleIdentifier ?? "io.dictate.app"
        let frontmostBundleId = TextInputService.getFrontmostAppBundleId()

        if let bundleId = frontmostBundleId, bundleId == selfBundleId {
            // Frontmost app is Dictate itself -- keep previously stored app if available
        } else {
            previousFrontApp = capturedApp
        }

        // Check microphone permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch authStatus {
        case .authorized:
            break
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
            logger.warning("[AppState] Unknown microphone authorization status")
            break
        }

        // Also check accessibility permission
        let accessibilityGranted = TextInputService.checkAccessibilityPermission()
        if !accessibilityGranted {
            // Request permission (shows system dialog)
            TextInputService.requestAccessibilityPermission()
        }

        // Show overlay
        let overlayView = OverlayView(
            appState: self,
            onCancel: { [weak self] in self?.cancelRecording() },
            onConfirm: { [weak self] in self?.stopRecording() }
        )
        overlayController.showOverlay(content: overlayView)

        // Start Escape key monitoring (recording-only; prevents system-wide Escape theft)
        startEscapeMonitoring()

        // Start audio recording
        try audioRecorder.startRecording()

        // Start audio level observation for waveform
        startAudioLevelObservation()

        // Start Deepgram streaming if key available
        let settings = AppSettings.load()
        startDeepgramIfAvailable(settings: settings)

        // status is already .recording (set in startRecording() to prevent double-trigger)
        interimText = ""
        confirmedInterimText = ""
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

    // Internal: used by AppState extensions only
    func performStopRecording() async throws {

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

        // Transcribe with Gemini via injected TranscriptionService
        guard let service = transcriptionService else {
            errorMessage = "Gemini APIキーが設定されていません"
            status = .error
            overlayController.hideOverlay()
            return
        }
        let dictionaryPrompt = dictionaryService.getDictionaryPrompt()
        let text = try await service.transcribeAudio(
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

        // Hide overlay before typing so the target app is fully focused
        overlayController.hideOverlay()

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

        logger.info("[AppState] Transcription complete (\(processedText.count) chars)")
    }

    // Internal: used by AppState extensions only
    func startDeepgramIfAvailable(settings: AppSettings) {
        guard let apiKey = try? keychainService.retrieve(key: KeychainService.deepgramKeyName) else {
            return
        }

        let language = settings.language.rawValue

        let service = DeepgramService()
        service.onTranscript = { [weak self] transcript in
            DispatchQueue.main.async {
                guard let self else { return }
                if transcript.isFinal {
                    // Append confirmed text to accumulated buffer
                    if !self.confirmedInterimText.isEmpty {
                        self.confirmedInterimText += " "
                    }
                    self.confirmedInterimText += transcript.text
                    self.interimText = self.confirmedInterimText
                } else {
                    // Show accumulated confirmed text + latest partial result
                    if self.confirmedInterimText.isEmpty {
                        self.interimText = transcript.text
                    } else {
                        self.interimText = self.confirmedInterimText + " " + transcript.text
                    }
                }
            }
        }
        service.onError = { [weak self] error in
            self?.logger.error("[AppState] Deepgram error: \(error.localizedDescription)")
        }

        Task { await service.connect(apiKey: apiKey, language: language) }
        deepgramService = service
    }

    // MARK: - Escape Key Monitoring

    /// Starts monitoring the Escape key during recording only.
    /// Uses NSEvent monitors so the key is NOT globally consumed when not recording.
    // Internal: used by AppState extensions only
    func startEscapeMonitoring() {
        stopEscapeMonitoring()
        // Global monitor: catches Escape when another app is frontmost
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 { // kVK_Escape
                DispatchQueue.main.async { self?.cancelRecording() }
            }
        }) {
            escapeMonitors.append(global)
        }
        // Local monitor: catches Escape when Dictate window/menu is frontmost
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { self?.cancelRecording() }
                return nil // consume the event so it doesn't propagate
            }
            return event
        }) {
            escapeMonitors.append(local)
        }
    }

    /// Stops all Escape key monitors.
    // Internal: used by AppState extensions only
    func stopEscapeMonitoring() {
        for monitor in escapeMonitors {
            NSEvent.removeMonitor(monitor)
        }
        escapeMonitors.removeAll()
    }
}
