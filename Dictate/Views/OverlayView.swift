import SwiftUI

struct OverlayView: View {
    let appState: AppState
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

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
