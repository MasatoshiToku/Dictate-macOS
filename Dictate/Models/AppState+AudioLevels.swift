import Foundation

// MARK: - Audio Level Management
// Internal: used by AppState extensions only

extension AppState {

    /// Downsample 24-bar recorder levels to 36-bar display levels (interpolated + amplified)
    // Internal: used by AppState extensions only
    func downsampleLevels(_ recorderLevels: [Float]) -> [Float] {
        let displayBarCount = 36
        let sourceBarCount = recorderLevels.count
        guard sourceBarCount > 0 else { return [Float](repeating: 0, count: displayBarCount) }
        var mappedLevels = [Float](repeating: 0, count: displayBarCount)
        for i in 0..<displayBarCount {
            // Map display bar index to source position using linear interpolation
            let srcPos = Float(i) * Float(sourceBarCount - 1) / Float(displayBarCount - 1)
            let lowerIdx = Int(srcPos)
            let upperIdx = min(lowerIdx + 1, sourceBarCount - 1)
            let frac = srcPos - Float(lowerIdx)
            let interpolated = recorderLevels[lowerIdx] * (1.0 - frac) + recorderLevels[upperIdx] * frac
            // Final amplification: boost levels for more dramatic visual movement
            mappedLevels[i] = min(interpolated * 1.5, 1.0)
        }
        return mappedLevels
    }

    /// Start audio level observation (called when recording begins).
    /// Uses a direct callback from AudioRecorderService (push model) as primary mechanism,
    /// plus a DispatchSourceTimer as a reliable fallback that doesn't depend on RunLoop.
    // Internal: used by AppState extensions only
    func startAudioLevelObservation() {
        stopAudioLevelObservation()

        // Primary: direct callback from AudioRecorderService (called on main thread)
        audioRecorder.onAudioLevelsUpdated = { [weak self] recorderLevels in
            guard let self, self.status == .recording else { return }
            let mapped = self.downsampleLevels(recorderLevels)
            self.audioLevels = mapped
        }

        // Fallback: DispatchSourceTimer on main queue (reliable even in Swift Concurrency)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33))
        timer.setEventHandler { [weak self] in
            guard let self, self.status == .recording else { return }
            let recorderLevels = self.audioRecorder.audioLevels
            let mapped = self.downsampleLevels(recorderLevels)
            // Only update and redraw if levels actually changed (avoid redundant @Observable triggers)
            if mapped != self.audioLevels {
                self.audioLevels = mapped
                // Force NSHostingView to redraw by invalidating the panel's content view
                self.overlayController.invalidateDisplay()
            }
        }
        timer.resume()
        audioLevelTimer = timer
    }

    // Internal: used by AppState extensions only
    func stopAudioLevelObservation() {
        audioRecorder.onAudioLevelsUpdated = nil
        audioLevelTimer?.cancel()
        audioLevelTimer = nil
    }
}
