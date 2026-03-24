#if os(iOS)
import SwiftUI
import DictateCore

struct ContentView: View {
    @Bindable var viewModel: DictationViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main recording area
                VStack(spacing: 24) {
                    Spacer()

                    // Status text
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    // Waveform
                    if viewModel.status == .recording {
                        HStack(spacing: 3) {
                            ForEach(0..<viewModel.audioLevels.count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange.gradient)
                                    .frame(width: 4, height: barHeight(viewModel.audioLevels[i]))
                                    .animation(.easeOut(duration: 0.075), value: viewModel.audioLevels[i])
                            }
                        }
                        .frame(height: 60)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }

                    // Interim text during recording
                    if !viewModel.interimText.isEmpty && viewModel.status == .recording {
                        Text(viewModel.interimText)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    // Processing indicator
                    if viewModel.status == .processing {
                        ProgressView("Transcribing...")
                            .transition(.opacity)
                    }

                    // Latest result
                    if !viewModel.transcriptionResult.isEmpty {
                        VStack(spacing: 12) {
                            Text(viewModel.transcriptionResult)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)

                            HStack(spacing: 12) {
                                Button(action: {
                                    viewModel.copyToClipboard()
                                    triggerHaptic(.success)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)

                                ShareLink(item: viewModel.transcriptionResult) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }

                    Spacer()

                    // Record button
                    Button(action: {
                        let isRecording = viewModel.status == .recording
                        triggerHaptic(isRecording ? .warning : .success)
                        viewModel.toggleRecording()
                    }) {
                        ZStack {
                            // Pulse ring animation while recording
                            if viewModel.status == .recording {
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 4)
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(pulseScale)
                                    .opacity(2 - pulseScale)
                                    .animation(
                                        .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                                        value: pulseScale
                                    )
                            }

                            Circle()
                                .fill(viewModel.status == .recording ? Color.red : Color.orange)
                                .frame(width: 80, height: 80)
                                .shadow(color: (viewModel.status == .recording ? Color.red : Color.orange).opacity(0.4), radius: 8, y: 4)

                            Image(systemName: viewModel.status == .recording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .disabled(viewModel.status == .processing)
                    .scaleEffect(buttonScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.status)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Transcription history list
                if !viewModel.historyEntries.isEmpty {
                    Divider()
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("History")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.historyEntries) { entry in
                                    HistoryRow(entry: entry) {
                                        UIPasteboard.general.string = entry.formattedText
                                        triggerHaptic(.success)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: 240)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.status)
            .navigationTitle("Dictate")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                IOSSettingsView()
            }
            .onAppear {
                viewModel.initialize()
                startPulse()
            }
        }
    }

    @State private var showSettings = false
    @State private var pulseScale: CGFloat = 1.0

    private var statusText: String {
        switch viewModel.status {
        case .idle: return "Tap to record"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        case .done: return "Done"
        case .error: return "Error"
        }
    }

    private var buttonScale: CGFloat {
        switch viewModel.status {
        case .recording: return 1.1
        case .processing: return 0.9
        default: return 1.0
        }
    }

    private func barHeight(_ level: Float) -> CGFloat {
        let min: CGFloat = 4
        let max: CGFloat = 50
        return Swift.min(max, Swift.max(min, CGFloat(level) * (max - min) + min))
    }

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    private func startPulse() {
        pulseScale = 2.0
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let entry: TranscriptionHistoryEntry
    let onCopy: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedText)
                    .font(.subheadline)
                    .lineLimit(2)

                Text(entry.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }

            Spacer()

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
#endif
