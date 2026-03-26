import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let isRecording: Bool
    let barCount: Int = 36

    // Breathing animation state for idle/quiet moments
    @State private var breathingPhase: Double = 0

    // Flatter bell curve (sigma 3.0) so ALL bars move significantly
    // Computed once as a static constant to avoid 36 exp() calls per frame (~720/sec at 20fps)
    private static let bellCurve: [Float] = (0..<36).map { i in
        let x = Float(i) / Float(36 - 1) * 2.0 - 1.0
        return exp(-x * x / (2.0 * 3.0 * 3.0)) // sigma = 3.0
    }

    // Check if audio is effectively silent
    private var isQuiet: Bool {
        levels.allSatisfy { $0 < 0.05 }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(levels.count, barCount), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isRecording ? Color(nsColor: .systemYellow) : Color.white.opacity(0.18))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(.easeInOut(duration: 1.2), value: breathingPhase)
            }
        }
        .animation(.easeOut(duration: 0.05), value: levels)
        .frame(height: 46)
        .onAppear {
            // Start breathing animation loop
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breathingPhase = 1.0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = index < levels.count ? levels[index] : 0
        let weight = index < Self.bellCurve.count ? Self.bellCurve[index] : 0.5
        let minHeight: CGFloat = 2
        let maxHeight: CGFloat = 42

        // When recording but quiet, show gentle breathing sine wave
        if isRecording && isQuiet {
            let phase = breathingPhase
            let sineOffset = sin(Double(index) * 0.4 + phase * .pi * 2.0)
            let breathHeight = minHeight + CGFloat(sineOffset + 1.0) * 3.0 * CGFloat(weight)
            return max(minHeight, min(maxHeight, breathHeight))
        }

        let height = minHeight + CGFloat(level * weight) * (maxHeight - minHeight)
        return max(minHeight, min(maxHeight, height))
    }
}

struct StatusDotsView: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(opacity(for: i)))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        switch index {
        case 0: return 0.55
        case 1: return 0.35
        case 2: return 0.18
        case 3: return 0.08
        default: return 0.04
        }
    }
}
