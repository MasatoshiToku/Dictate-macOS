import Testing
import Foundation
@testable import DictateCore

@Suite("DeepgramService")
struct DeepgramServiceTests {

    // MARK: - Connection State Tests

    @Test("New service should not be connected")
    func initialStateNotConnected() {
        let service = DeepgramService()
        #expect(!service.connectedStatus)
    }

    @Test("Close on disconnected service should not crash")
    func closeOnDisconnected() {
        let service = DeepgramService()
        // Should be safe to call close() even when not connected
        service.close()
        #expect(!service.connectedStatus)
    }

    // MARK: - Callback Configuration Tests

    @Test("Callbacks should be settable")
    func callbacksSettable() {
        let service = DeepgramService()

        var transcriptReceived = false

        service.onTranscript = { _ in transcriptReceived = true }
        service.onError = { _ in }
        service.onClose = {}

        // Verify callbacks are set (non-nil)
        #expect(service.onTranscript != nil)
        #expect(service.onError != nil)
        #expect(service.onClose != nil)

        // Verify transcript callback can be invoked
        service.onTranscript?(DeepgramService.Transcript(text: "test", isFinal: true))
        #expect(transcriptReceived)
    }

    // MARK: - Transcript Model Tests

    @Test("Transcript model stores text and isFinal correctly")
    func transcriptModel() {
        let interim = DeepgramService.Transcript(text: "hello", isFinal: false)
        #expect(interim.text == "hello")
        #expect(!interim.isFinal)

        let final = DeepgramService.Transcript(text: "hello world", isFinal: true)
        #expect(final.text == "hello world")
        #expect(final.isFinal)
    }

    @Test("Empty transcript text is valid")
    func emptyTranscript() {
        let transcript = DeepgramService.Transcript(text: "", isFinal: true)
        #expect(transcript.text.isEmpty)
        #expect(transcript.isFinal)
    }

    // MARK: - Reconnection State Tests

    @Test("Multiple close calls should be safe")
    func multipleCloseCallsSafe() {
        let service = DeepgramService()
        service.close()
        service.close()
        service.close()
        #expect(!service.connectedStatus)
    }

    @Test("Send audio on disconnected service should not crash")
    func sendAudioDisconnected() {
        let service = DeepgramService()
        let testData = Data([0x00, 0x01, 0x02, 0x03])
        // Should silently return without crashing
        service.sendAudio(testData)
        #expect(!service.connectedStatus)
    }
}
