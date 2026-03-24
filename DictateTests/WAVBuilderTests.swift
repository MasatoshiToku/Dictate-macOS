import Foundation
import Testing
@testable import DictateCore

@Suite("WAVBuilder")
struct WAVBuilderTests {
    // MARK: - Header structure tests

    @Test("WAV header is exactly 44 bytes")
    func headerSize() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 16000, channels: 1)
        #expect(wav.count == 44)
    }

    @Test("RIFF marker at offset 0")
    func riffMarker() {
        let wav = WAVBuilder.buildWAV(pcmData: Data([0x00, 0x00]), sampleRate: 16000, channels: 1)
        let riff = String(bytes: Array(wav[0..<4]), encoding: .ascii)
        #expect(riff == "RIFF")
    }

    @Test("WAVE marker at offset 8")
    func waveMarker() {
        let wav = WAVBuilder.buildWAV(pcmData: Data([0x00, 0x00]), sampleRate: 16000, channels: 1)
        let wave = String(bytes: Array(wav[8..<12]), encoding: .ascii)
        #expect(wave == "WAVE")
    }

    @Test("fmt marker at offset 12")
    func fmtMarker() {
        let wav = WAVBuilder.buildWAV(pcmData: Data([0x00, 0x00]), sampleRate: 16000, channels: 1)
        let fmt = String(bytes: Array(wav[12..<16]), encoding: .ascii)
        #expect(fmt == "fmt ")
    }

    @Test("data marker at offset 36")
    func dataMarker() {
        let wav = WAVBuilder.buildWAV(pcmData: Data([0x00, 0x00]), sampleRate: 16000, channels: 1)
        let dataTag = String(bytes: Array(wav[36..<40]), encoding: .ascii)
        #expect(dataTag == "data")
    }

    // MARK: - Field value tests

    @Test("Audio format is PCM (1)")
    func audioFormatPCM() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 16000, channels: 1)
        let audioFormat = wav.withUnsafeBytes { $0.load(fromByteOffset: 20, as: UInt16.self) }
        #expect(UInt16(littleEndian: audioFormat) == 1)
    }

    @Test("Sample rate is correctly encoded")
    func sampleRateEncoded() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 16000, channels: 1)
        let sr = wav.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) }
        #expect(UInt32(littleEndian: sr) == 16000)
    }

    @Test("Channel count is correctly encoded")
    func channelCount() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 44100, channels: 2)
        let ch = wav.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) }
        #expect(UInt16(littleEndian: ch) == 2)
    }

    @Test("Bits per sample is correctly encoded")
    func bitsPerSample() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 16000, channels: 1, bitsPerSample: 16)
        let bps = wav.withUnsafeBytes { $0.load(fromByteOffset: 34, as: UInt16.self) }
        #expect(UInt16(littleEndian: bps) == 16)
    }

    @Test("Byte rate = sampleRate * channels * bytesPerSample")
    func byteRate() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 44100, channels: 2, bitsPerSample: 16)
        let br = wav.withUnsafeBytes { $0.load(fromByteOffset: 28, as: UInt32.self) }
        // 44100 * 2 * 2 = 176400
        #expect(UInt32(littleEndian: br) == 176400)
    }

    @Test("Block align = channels * bytesPerSample")
    func blockAlign() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 16000, channels: 2, bitsPerSample: 16)
        let ba = wav.withUnsafeBytes { $0.load(fromByteOffset: 32, as: UInt16.self) }
        // 2 channels * 2 bytes = 4
        #expect(UInt16(littleEndian: ba) == 4)
    }

    // MARK: - Data chunk size tests

    @Test("Data chunk size matches PCM input length")
    func dataChunkSize() {
        let pcm = Data(repeating: 0xAB, count: 1024)
        let wav = WAVBuilder.buildWAV(pcmData: pcm, sampleRate: 16000, channels: 1)
        let ds = wav.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }
        #expect(UInt32(littleEndian: ds) == 1024)
    }

    @Test("Total file size = 44 + pcmData.count")
    func totalFileSize() {
        let pcm = Data(repeating: 0x00, count: 512)
        let wav = WAVBuilder.buildWAV(pcmData: pcm, sampleRate: 16000, channels: 1)
        #expect(wav.count == 44 + 512)
    }

    @Test("RIFF chunk size field = fileSize - 8")
    func riffChunkSize() {
        let pcm = Data(repeating: 0x00, count: 256)
        let wav = WAVBuilder.buildWAV(pcmData: pcm, sampleRate: 16000, channels: 1)
        let riffSize = wav.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        // fileSize field = 36 + dataSize = 36 + 256 = 292
        #expect(UInt32(littleEndian: riffSize) == 292)
    }

    @Test("PCM data is appended after header")
    func pcmDataAppended() {
        let pcm = Data([0x01, 0x02, 0x03, 0x04])
        let wav = WAVBuilder.buildWAV(pcmData: pcm, sampleRate: 16000, channels: 1)
        let tail = Array(wav[44..<48])
        #expect(tail == [0x01, 0x02, 0x03, 0x04])
    }

    @Test("Empty PCM data produces header-only WAV")
    func emptyPCMData() {
        let wav = WAVBuilder.buildWAV(pcmData: Data(), sampleRate: 16000, channels: 1)
        #expect(wav.count == 44)
        let ds = wav.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }
        #expect(UInt32(littleEndian: ds) == 0)
    }
}
