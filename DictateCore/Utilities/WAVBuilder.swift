import Foundation

// MARK: - WAVBuilder

/// Constructs WAV file data from raw PCM samples.
/// Extracted from AudioRecorderService for testability.
public enum WAVBuilder {
    /// Create a complete WAV file (header + PCM data).
    /// - Parameters:
    ///   - pcmData: Raw PCM Int16 little-endian audio data
    ///   - sampleRate: Sample rate in Hz (e.g. 16000)
    ///   - channels: Number of audio channels (e.g. 1 for mono)
    ///   - bitsPerSample: Bits per sample (default 16)
    /// - Returns: Complete WAV file as Data
    public static func buildWAV(
        pcmData: Data,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int = 16
    ) -> Data {
        let bytesPerSample = bitsPerSample / 8
        let blockAlign = channels * bytesPerSample
        let byteRate = sampleRate * blockAlign
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize // Total file size minus 8 bytes for RIFF header

        var wav = Data()
        wav.reserveCapacity(44 + dataSize)

        // RIFF header
        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt sub-chunk
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // Sub-chunk size
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // Audio format (PCM)
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })  // Channels
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) }) // Sample rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })   // Byte rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) }) // Block align
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) }) // Bits per sample

        // data sub-chunk
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wav.append(pcmData)

        return wav
    }
}
