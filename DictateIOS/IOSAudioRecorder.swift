#if os(iOS)
import AVFoundation
import os

class IOSAudioRecorder {
    private let engine = AVAudioEngine()
    private var audioData = Data()
    private let logger = Logger(subsystem: "io.dictate.app", category: "ios-recorder")

    var onAudioLevels: (([Float]) -> Void)?
    var onAudioChunk: ((Data) -> Void)?
    var onInterrupted: (() -> Void)?

    private let barCount = 24
    private var chunkBuffer = Data()
    private let chunkInterval: Int = 4000 // frames per chunk (~250ms at 16kHz)
    private var isRecording = false

    init() {
        setupInterruptionHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Interruption

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            logger.warning("[IOSAudioRecorder] Audio session interrupted (e.g., phone call)")
            if isRecording {
                // Stop the engine to release audio resources
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
                isRecording = false
                // Notify the caller so it can handle the interruption in UI
                onInterrupted?()
            }
        case .ended:
            logger.info("[IOSAudioRecorder] Audio session interruption ended")
            // Do not auto-resume -- let the user restart manually
            // The interrupted audio would have gaps and produce bad transcription
        @unknown default:
            break
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        audioData = Data()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true) else {
            throw NSError(domain: "IOSAudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Convert to target format
            guard let converter = converter else { return }
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * 16000.0 / buffer.format.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, let int16Data = convertedBuffer.int16ChannelData else { return }

            let frameLength = Int(convertedBuffer.frameLength)
            let bytes = UnsafeRawPointer(int16Data.pointee)
            let data = Data(bytes: bytes, count: frameLength * 2)

            self.audioData.append(data)
            self.chunkBuffer.append(data)

            // Send chunks for Deepgram
            if self.chunkBuffer.count >= self.chunkInterval * 2 {
                self.onAudioChunk?(self.chunkBuffer)
                self.chunkBuffer = Data()
            }

            // Compute RMS levels
            var levels = [Float](repeating: 0, count: self.barCount)
            let segmentSize = max(1, frameLength / self.barCount)
            for i in 0..<self.barCount {
                let start = i * segmentSize
                let end = min((i + 1) * segmentSize, frameLength)
                var sum: Float = 0
                for j in start..<end {
                    let sample = Float(int16Data.pointee[j]) / 32768.0
                    sum += sample * sample
                }
                levels[i] = sqrt(sum / Float(max(1, end - start)))
            }
            self.onAudioLevels?(levels)
        }

        try engine.start()
        isRecording = true
        logger.info("iOS recording started")
    }

    func stop() async throws -> Data {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        // Build WAV
        let wavData = buildWAV(pcmData: audioData, sampleRate: 16000, channels: 1, bitsPerSample: 16)
        audioData = Data()

        logger.info("iOS recording stopped, WAV size: \(wavData.count)")
        return wavData
    }

    private func buildWAV(pcmData: Data, sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) -> Data {
        var header = Data()
        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36

        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        let blockAlign = channels * (bitsPerSample / 8)
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        return header + pcmData
    }
}
#endif
