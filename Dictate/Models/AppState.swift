import SwiftUI
import Observation
import os

/// Central application state coordinator.
/// Stub implementation for UI compilation — full wiring comes in Task 16.
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
    var audioLevels: [Float] = Array(repeating: 0.2, count: 24)

    // MARK: - Services
    let keychainService = KeychainService()
    let dictionaryService = DictionaryService()
    let historyService = HistoryService()

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
}
