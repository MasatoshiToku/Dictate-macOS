import Foundation
import os

// MARK: - GeminiServiceManager

/// Singleton management for GeminiService with API key validation
public final class GeminiServiceManager: Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "GeminiServiceManager")

    // nonisolated(unsafe) because we manage thread safety manually via the lock
    nonisolated(unsafe) private static var _shared: GeminiService?
    private static let lock = NSLock()

    public static let instance = GeminiServiceManager()

    private init() {}

    /// Initialize GeminiService with API key. Call at app startup or when key changes.
    public static func initialize(apiKey: String) {
        lock.lock()
        defer { lock.unlock() }
        _shared = GeminiService(apiKey: apiKey)
    }

    /// Get the shared GeminiService instance. Crashes if not initialized.
    public static var shared: GeminiService {
        lock.lock()
        defer { lock.unlock() }
        guard let service = _shared else {
            fatalError("[GeminiServiceManager] GeminiService not initialized. Call initialize(apiKey:) first.")
        }
        return service
    }

    /// Check if the service has been initialized
    public static var isInitialized: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _shared != nil
    }

    /// Validate API key by making a minimal test request
    public static func validateApiKey(_ apiKey: String) async -> (valid: Bool, error: String?) {
        let testService = GeminiService(apiKey: apiKey)

        // Create a tiny silent WAV to test the API key
        let silentWav = createSilentWAV(durationMs: 100, sampleRate: 16000)

        do {
            _ = try await testService.transcribeAudio(
                audioData: silentWav,
                mimeType: "audio/wav",
                dictionaryPrompt: ""
            )
            return (valid: true, error: nil)
        } catch let error as GeminiError {
            switch error {
            case .unauthorized, .invalidAPIKey:
                return (valid: false, error: "API key is invalid or unauthorized")
            case .rateLimited:
                // Rate limited means the key is valid, just overused
                return (valid: true, error: nil)
            default:
                // Other errors (server errors, etc.) don't necessarily mean invalid key
                return (valid: true, error: "Key seems valid but got: \(error.localizedDescription)")
            }
        } catch {
            return (valid: false, error: "Validation failed: \(error.localizedDescription)")
        }
    }

    /// Create a minimal silent WAV file for API key validation
    private static func createSilentWAV(durationMs: Int, sampleRate: Int) -> Data {
        let numSamples = sampleRate * durationMs / 1000
        let dataSize = numSamples * 2 // 16-bit = 2 bytes per sample
        let fileSize = 36 + dataSize

        var data = Data()

        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM format
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) }) // sample rate
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) }) // byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        data.append(Data(count: dataSize)) // silent samples (all zeros)

        return data
    }
}
