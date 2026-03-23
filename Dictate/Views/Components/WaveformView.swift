import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let isRecording: Bool
    let barCount: Int = 24

    // Bell curve weights -- bars in the center are taller for visual appeal
    private var bellCurve: [Float] {
        (0..<barCount).map { i in
            let x = Float(i) / Float(barCount - 1) * 2.0 - 1.0
            return exp(-x * x * 2.0)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(levels.count, barCount), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isRecording ? Color(nsColor: .systemYellow) : Color.white.opacity(0.18))
                    .frame(width: 2, height: barHeight(for: i))
                    .animation(.easeOut(duration: 0.075), value: levels[i])
            }
        }
        .frame(height: 32)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = index < levels.count ? levels[index] : 0
        let weight = index < bellCurve.count ? bellCurve[index] : 0.5
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 28
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
