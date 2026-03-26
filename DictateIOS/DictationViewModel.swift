#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit
import DictateCore

@Observable
final class DictationViewModel {
    enum Status: String {
        case idle, recording, processing, done, error
    }

    var status: Status = .idle
    var interimText: String = ""
    var transcriptionResult: String = ""
    var errorMessage: String?
    var audioLevels: [Float] = Array(repeating: 0, count: 24)
    var hasGeminiKey: Bool = false
    var historyEntries: [TranscriptionHistoryEntry] = []

    private var audioRecorder: IOSAudioRecorder?
    private var deepgramService: DeepgramService?
    private let keychainService = KeychainService()

    func initialize() {
        // Check for API key
        hasGeminiKey = keychainService.has(key: KeychainService.geminiKeyName)
        if let apiKey = try? keychainService.retrieve(key: KeychainService.geminiKeyName) {
            GeminiServiceManager.initialize(apiKey: apiKey)
        }
        // Load transcription history
        historyEntries = HistoryService().getAll()
    }

    func toggleRecording() {
        switch status {
        case .idle, .done:
            startRecording()
        case .recording:
            stopRecording()
        default:
            break
        }
    }

    func startRecording() {
        guard status == .idle || status == .done else { return }
        guard GeminiServiceManager.isInitialized else {
            errorMessage = "Gemini APIキーを設定してください"
            return
        }

        Task { @MainActor in
            do {
                let recorder = IOSAudioRecorder()
                recorder.onAudioLevels = { [weak self] levels in
                    DispatchQueue.main.async { self?.audioLevels = levels }
                }
                recorder.onAudioChunk = { [weak self] chunk in
                    self?.deepgramService?.sendAudio(chunk)
                }
                recorder.onInterrupted = { [weak self] in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.deepgramService?.close()
                        self.deepgramService = nil
                        self.audioRecorder = nil
                        self.status = .idle
                        self.errorMessage = "録音が中断されました（通話等）"
                    }
                }

                try recorder.start()
                self.audioRecorder = recorder

                // Start Deepgram if available
                startDeepgramIfAvailable()

                status = .recording
                interimText = ""
                transcriptionResult = ""
                errorMessage = nil
            } catch {
                errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func stopRecording() {
        guard status == .recording else { return }
        status = .processing

        Task { @MainActor in
            do {
                deepgramService?.close()
                deepgramService = nil

                guard let audioData = try await audioRecorder?.stop() else {
                    status = .idle
                    return
                }

                let gemini = GeminiServiceManager.shared
                let dictionaryPrompt = DictionaryService().getDictionaryPrompt()
                let text = try await gemini.transcribeAudio(
                    audioData: audioData,
                    mimeType: "audio/wav",
                    dictionaryPrompt: dictionaryPrompt
                )

                guard !text.isEmpty else {
                    status = .idle
                    return
                }

                let processed = TextProcessing.removeJapaneseSpaces(text)
                transcriptionResult = processed

                let history = HistoryService()
                history.add(originalText: text, formattedText: processed)
                historyEntries = history.getAll()

                status = .done

                // Haptic feedback on successful transcription
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = "文字起こしに失敗しました: \(error.localizedDescription)"
                status = .error
            }
        }
    }

    func copyToClipboard() {
        UIPasteboard.general.string = transcriptionResult
    }

    private func startDeepgramIfAvailable() {
        guard let apiKey = try? keychainService.retrieve(key: KeychainService.deepgramKeyName) else { return }
        let service = DeepgramService()
        service.onTranscript = { [weak self] transcript in
            DispatchQueue.main.async { self?.interimText = transcript.text }
        }
        Task { await service.connect(apiKey: apiKey, language: "ja") }
        deepgramService = service
    }
}
#endif
