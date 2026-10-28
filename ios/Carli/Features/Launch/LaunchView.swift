import SwiftUI

/// Launch animation: the face blinks twice while the wordmark rises in, then fades
/// away. Waits until the session is resolved; a tap skips it.
struct LaunchView: View {
    var ready: Bool
    var onFinish: () -> Void

    static let duration: TimeInterval = 1.5
    static let faceSize: CGFloat = 96
    private static let blinks: [(start: Double, end: Double)] = [(0.30, 0.40), (0.48, 0.58)]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            let progress = progress(at: timeline.date)
            ZStack {
                CarliColor.bg.ignoresSafeArea()
                CarliLogo(size: Self.faceSize, eyeOpenness: Self.eyeOpenness(progress))
                Text("carli")
                    .carliWordmark(22)
                    .foregroundStyle(CarliColor.text)
                    .opacity(Self.wordmark(progress))
                    .offset(y: Self.faceSize / 2 + 28 + 6 * (1 - Self.wordmark(progress)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if start != nil { onFinish() } }
        .accessibilityElement()
        .accessibilityLabel("carli")
        .onChange(of: ready, initial: true) { _, ready in
            guard ready, start == nil else { return }
            if reduceMotion {
                onFinish()
                return
            }
            start = .now
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                onFinish()
            }
        }
    }

    private func progress(at date: Date) -> Double {
        guard let start else { return 0 }
        return min(1, date.timeIntervalSince(start) / Self.duration)
    }

    static func eyeOpenness(_ progress: Double) -> CGFloat {
        for blink in blinks where progress >= blink.start && progress <= blink.end {
            let t = (progress - blink.start) / (blink.end - blink.start)
            return abs(2 * t - 1)
        }
        return 1
    }

    static func wordmark(_ progress: Double) -> Double {
        let t = min(1, max(0, (progress - 0.15) / 0.3))
        return 1 - pow(1 - t, 3)
    }
}

#Preview {
    LaunchView(ready: true) {}
}
