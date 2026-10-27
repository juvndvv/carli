import SwiftUI

/// A single activity ring (Fitness style): faint track, coloured arc from the top.
struct ActivityRing: View {
    var progress: Double
    var color: Color = CarliColor.rings[0]
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.9), value: progress)
    }
}
