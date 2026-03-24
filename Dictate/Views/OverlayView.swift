import SwiftUI

struct OverlayView: View {
    let appState: AppState
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var recordingStartDate = Date()
    @State private var elapsedSeconds: Int = 0
    @State private var durationTimer: Timer?

    private var formattedDuration: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Recording duration
            if appState.isRecording {
                Text(formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 4)
                    .onAppear {
                        recordingStartDate = Date()
                        elapsedSeconds = 0
                        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                            elapsedSeconds = Int(Date().timeIntervalSince(recordingStartDate))
                        }
                    }
                    .onDisappear {
                        durationTimer?.invalidate()
                        durationTimer = nil
                    }
            }

            // Interim text preview
            if showInterimText {
                Text(appState.interimText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 480, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.93))
                    )
                    .padding(.bottom, 6)
            }

            // Waveform bar with controls
            HStack(spacing: 12) {
                // Cancel button
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.1)))

                // Waveform or status dots
                if appState.isProcessing || appState.isTyping {
                    StatusDotsView()
                        .frame(maxWidth: .infinity)
                } else {
                    WaveformView(
                        levels: appState.audioLevels,
                        isRecording: appState.isRecording
                    )
                    .frame(maxWidth: .infinity)
                }

                // Confirm/Stop button
                Button(action: onConfirm) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(appState.isRecording ? .yellow : .white.opacity(0.12))
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))
            )
            .padding(.bottom, 8)
        }
        .frame(width: 500, height: 200)
    }

    private var showInterimText: Bool {
        (appState.isRecording || appState.isProcessing) && !appState.interimText.isEmpty
    }
}
