import Foundation

/// Protocol for audio transcription services.
/// Enables dependency injection and mocking for tests.
public protocol TranscriptionService: Sendable {
    func transcribeAudio(audioData: Data, mimeType: String, dictionaryPrompt: String) async throws -> String
}
