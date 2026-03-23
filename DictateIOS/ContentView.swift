#if os(iOS)
import SwiftUI
import DictateCore

struct ContentView: View {
    @Bindable var viewModel: DictationViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Status text
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(.secondary)

                // Waveform
                if viewModel.status == .recording {
                    HStack(spacing: 3) {
                        ForEach(0..<viewModel.audioLevels.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange)
                                .frame(width: 4, height: barHeight(viewModel.audioLevels[i]))
                                .animation(.easeOut(duration: 0.075), value: viewModel.audioLevels[i])
                        }
                    }
                    .frame(height: 60)
                }

                // Interim text during recording
                if !viewModel.interimText.isEmpty && viewModel.status == .recording {
                    Text(viewModel.interimText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // Processing indicator
                if viewModel.status == .processing {
                    ProgressView("文字起こし中...")
                }

                // Result
                if !viewModel.transcriptionResult.isEmpty {
                    VStack(spacing: 12) {
                        Text(viewModel.transcriptionResult)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        Button(action: viewModel.copyToClipboard) {
                            Label("コピー", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                }

                // Error
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()

                // Record button
                Button(action: viewModel.toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(viewModel.status == .recording ? Color.red : Color.orange)
                            .frame(width: 80, height: 80)

                        Image(systemName: viewModel.status == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .disabled(viewModel.status == .processing)
                .padding(.bottom, 40)
            }
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
            }
        }
    }

    @State private var showSettings = false

    private var statusText: String {
        switch viewModel.status {
        case .idle: return "タップして録音開始"
        case .recording: return "録音中..."
        case .processing: return "処理中..."
        case .done: return "完了"
        case .error: return "エラー"
        }
    }

    private func barHeight(_ level: Float) -> CGFloat {
        let min: CGFloat = 4
        let max: CGFloat = 50
        return Swift.min(max, Swift.max(min, CGFloat(level) * (max - min) + min))
    }
}
#endif
