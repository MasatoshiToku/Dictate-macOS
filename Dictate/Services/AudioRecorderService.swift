import AVFoundation
import DictateCore
import Combine
import Foundation
import os

// MARK: - AudioRecorderService Errors

enum AudioRecorderError: Error, LocalizedError {
    case engineStartFailed(Error)
    case noAudioData
    case notRecording
    case wavWriteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .engineStartFailed(let error): return "Failed to start audio engine: \(error.localizedDescription)"
        case .noAudioData: return "No audio data captured"
        case .notRecording: return "Not currently recording"
        case .wavWriteFailed(let error): return "Failed to write WAV file: \(error.localizedDescription)"
        }
    }
}

// MARK: - AudioRecorderService

final class AudioRecorderService: ObservableObject {
    private let logger = Logger(subsystem: "io.dictate.app", category: "AudioRecorderService")

    // Published properties (updated on main thread)
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 24)

    // Audio engine
    private let audioEngine = AVAudioEngine()
    private var recordedBuffers: [AVAudioPCMBuffer] = []
    private let bufferLock = NSLock()

    // Audio format: PCM Int16, 16kHz, mono
    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1

    // Waveform visualization
    private let barCount = 24
    private let smoothingFactor: Float = 0.3 // Exponential decay smoothing

    // Streaming chunks for Deepgram
    var onAudioChunk: ((Data) -> Void)?
    private let chunkIntervalSamples: Int // ~250ms of audio per chunk
    private var pendingChunkSamples: Int = 0
    private var chunkBuffer = Data()

    // Temp file path
    private let tempFileURL: URL

    init() {
        self.chunkIntervalSamples = Int(16000 * 0.25) // 250ms at 16kHz
        self.tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("dictate-recording.wav")
    }

    // MARK: - Recording Control

    /// Start recording audio via AVAudioEngine
    func startRecording() throws {
        guard !isRecording else {
            logger.warning("[AudioRecorderService] Already recording")
            return
        }

        do {
            resetState()

            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Create target format: PCM Float32 at 16kHz mono (for processing)
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: targetChannels,
                interleaved: false
            ) else {
                throw AudioRecorderError.engineStartFailed(
                    NSError(domain: "AudioRecorderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
                )
            }

            // Install converter if sample rate or channels differ
            let converter: AVAudioConverter?
            if inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != targetChannels {
                converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            } else {
                converter = nil
            }

            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }

            try audioEngine.start()

            DispatchQueue.main.async { [weak self] in
                self?.isRecording = true
            }
            logger.info("[AudioRecorderService] Recording started")
        } catch {
            logger.error("[AudioRecorderService] startRecording failed: \(error.localizedDescription)")
            throw AudioRecorderError.engineStartFailed(error)
        }
    }

    /// Stop recording and return captured audio as WAV data
    func stopRecording() async throws -> Data {
        guard isRecording else {
            throw AudioRecorderError.notRecording
        }

        do {
            stopEngine()

            // Flush remaining chunk data
            if !chunkBuffer.isEmpty, let onChunk = onAudioChunk {
                let remaining = chunkBuffer
                chunkBuffer = Data()
                onChunk(remaining)
            }

            let wavData = try buildWAVData()
            logger.info("[AudioRecorderService] Recording stopped, WAV size: \(wavData.count) bytes")
            return wavData
        } catch {
            logger.error("[AudioRecorderService] stopRecording failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Cancel recording without returning data
    func cancelRecording() {
        stopEngine()
        logger.info("[AudioRecorderService] Recording cancelled")
    }

    // MARK: - Audio Processing (background thread)

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        targetFormat: AVAudioFormat
    ) {
        let convertedBuffer: AVAudioPCMBuffer

        if let converter = converter {
            // Convert to target format
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate
            )
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
                return
            }

            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .error, let error = conversionError {
                logger.error("[AudioRecorderService] Audio conversion error: \(error.localizedDescription)")
                return
            }
            convertedBuffer = outputBuffer
        } else {
            convertedBuffer = buffer
        }

        // Store buffer for final WAV assembly
        bufferLock.lock()
        recordedBuffers.append(convertedBuffer)
        bufferLock.unlock()

        // Compute RMS levels for waveform visualization
        updateAudioLevels(from: convertedBuffer)

        // Send chunks for Deepgram streaming
        sendChunkIfNeeded(from: convertedBuffer)
    }

    // MARK: - Waveform Levels

    private func updateAudioLevels(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let segmentSize = max(frameCount / barCount, 1)
        var newLevels = [Float](repeating: 0, count: barCount)

        for i in 0..<barCount {
            let start = i * segmentSize
            let end = min((i + 1) * segmentSize, frameCount)
            guard start < frameCount else { break }

            var sum: Float = 0
            for j in start..<end {
                let sample = channelData[j]
                sum += sample * sample
            }
            newLevels[i] = sqrt(sum / Float(end - start))
        }

        // Apply exponential smoothing on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var smoothed = self.audioLevels
            for i in 0..<self.barCount {
                if i < newLevels.count {
                    smoothed[i] = self.smoothingFactor * newLevels[i] + (1.0 - self.smoothingFactor) * smoothed[i]
                } else {
                    // Decay toward zero if no new data for this bar
                    smoothed[i] *= (1.0 - self.smoothingFactor)
                }
            }
            self.audioLevels = smoothed
        }
    }

    // MARK: - Streaming Chunks

    private func sendChunkIfNeeded(from buffer: AVAudioPCMBuffer) {
        guard let onChunk = onAudioChunk else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Convert Float32 to Int16 PCM for streaming
        let int16Data = convertToInt16(channelData: channelData, frameCount: frameCount)
        chunkBuffer.append(int16Data)
        pendingChunkSamples += frameCount

        // Send when we have ~250ms of audio
        if pendingChunkSamples >= chunkIntervalSamples {
            let chunk = chunkBuffer
            chunkBuffer = Data()
            pendingChunkSamples = 0
            onChunk(chunk)
        }
    }

    // MARK: - WAV Construction

    private func buildWAVData() throws -> Data {
        bufferLock.lock()
        let buffers = recordedBuffers
        bufferLock.unlock()

        guard !buffers.isEmpty else {
            throw AudioRecorderError.noAudioData
        }

        // Calculate total samples
        var totalFrames = 0
        for buffer in buffers {
            totalFrames += Int(buffer.frameLength)
        }

        // Convert all buffers to Int16 PCM
        var pcmData = Data()
        pcmData.reserveCapacity(totalFrames * 2)

        for buffer in buffers {
            guard let channelData = buffer.floatChannelData?[0] else { continue }
            let frameCount = Int(buffer.frameLength)
            let int16Data = convertToInt16(channelData: channelData, frameCount: frameCount)
            pcmData.append(int16Data)
        }

        // Build WAV with proper header
        return WAVBuilder.buildWAV(pcmData: pcmData, sampleRate: Int(targetSampleRate), channels: Int(targetChannels))
    }

    private func convertToInt16(channelData: UnsafePointer<Float>, frameCount: Int) -> Data {
        var data = Data(count: frameCount * 2)
        data.withUnsafeMutableBytes { rawBuffer in
            guard let ptr = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }
            for i in 0..<frameCount {
                // Clamp float [-1.0, 1.0] to Int16 range
                let clamped = max(-1.0, min(1.0, channelData[i]))
                ptr[i] = Int16(clamped * Float(Int16.max))
            }
        }
        return data
    }

    // MARK: - Internal Helpers

    private func resetState() {
        bufferLock.lock()
        recordedBuffers.removeAll()
        bufferLock.unlock()
        chunkBuffer = Data()
        pendingChunkSamples = 0
        DispatchQueue.main.async { [weak self] in
            self?.audioLevels = Array(repeating: 0, count: self?.barCount ?? 24)
        }
    }

    private func stopEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.audioLevels = Array(repeating: 0, count: self?.barCount ?? 24)
        }
    }
}
