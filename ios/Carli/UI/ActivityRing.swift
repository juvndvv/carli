import SwiftUI

/// A single activity ring (Fitness style): faint track, coloured arc from the top.
/// Progress above 1 draws a second lap over the first, as Fitness does.
struct ActivityRing: View {
    var progress: Double?
    var color: Color = CarliColor.rings[0]
    var lineWidth: CGFloat = 6

    var body: some View {
        let value = max(0, progress ?? 0)
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            arc(to: min(value, 1))
            if value > 1 {
                arc(to: min(value - 1, 1), color: color.mix(with: .black, by: 0.25))
                    .shadow(color: .black.opacity(0.35), radius: 3)
            }
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.9), value: value)
    }

    private func arc(to end: Double, color: Color? = nil) -> some View {
        Circle()
            .trim(from: 0, to: max(0.001, end))
            .stroke(color ?? self.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

/// Concentric rings, outer to inner, each `lineWidth` thick with a small gap.
struct RingStack: View {
    var values: [(Double?, Color)]
    var size: CGFloat = 136
    var lineWidth: CGFloat = 15

    var body: some View {
        ZStack {
            ForEach(values.indices, id: \.self) { index in
                let inset = CGFloat(index) * (lineWidth + 2)
                ActivityRing(progress: values[index].0, color: values[index].1, lineWidth: lineWidth)
                    .frame(width: size - inset * 2, height: size - inset * 2)
            }
        }
        .frame(width: size, height: size)
    }
}
