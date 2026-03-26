import SwiftUI

struct OverlayView: View {
    let appState: AppState
    let onCancel: () -> Void
    let onConfirm: () -> Void

    // Overlay size — values defined in OverlayConstants (OverlayPanel.swift)
    private let overlayWidth = OverlayConstants.width
    private let overlayHeight = OverlayConstants.height

    var body: some View {
        VStack(spacing: 0) {
            // Interim text area (shown when available during recording/processing)
            if (appState.isRecording || appState.isProcessing) && !appState.interimText.isEmpty {
                ScrollView {
                    Text(appState.interimText)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: overlayWidth - 28, alignment: .leading)
                }
                .frame(maxWidth: overlayWidth - 20, maxHeight: overlayHeight - 60, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer()

            // Control bar: [X] [waveform] [stop]
            HStack(spacing: 8) {
                // Cancel button
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(width: 26, height: 26)
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

                // Stop button
                Button(action: onConfirm) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(appState.isRecording ? .yellow : .white.opacity(0.12))
                }
                .buttonStyle(.plain)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.85))
            )
            .padding(.bottom, 6)
        }
        .frame(width: overlayWidth, height: overlayHeight)
    }
}
