import SwiftUI

/// The carli mark: a lime tile with a bold ink "c" and two eyes peeking inside it,
/// the same drawing as the app icon. `eyeOpenness` drives the launch blink (1 open, 0 closed).
struct CarliLogo: View {
    var size: CGFloat = 30
    var eyeOpenness: CGFloat = 1

    var body: some View {
        Canvas { context, canvasSize in
            // The tile spans 12–88 of a 100 grid; `p` maps the icon's own 0–100 grid into it.
            let s = canvasSize.width / 100
            let p = { (u: CGFloat) in (12 + 0.76 * u) * s }
            let tile = Path(roundedRect: CGRect(x: 12 * s, y: 12 * s, width: 76 * s, height: 76 * s),
                            cornerRadius: 18 * s, style: .continuous)
            context.fill(tile, with: .linearGradient(
                Gradient(colors: [CarliColor.brandLight, CarliColor.brand]),
                startPoint: CGPoint(x: 0, y: 12 * s), endPoint: CGPoint(x: 0, y: 88 * s)))

            var c = Path()
            c.addArc(center: CGPoint(x: p(50), y: p(50)), radius: 27 * 0.76 * s,
                     startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: true)
            context.stroke(c, with: .color(CarliColor.onBrand),
                           style: StrokeStyle(lineWidth: 15 * 0.76 * s, lineCap: .round))

            let eyeHeight = 11.2 * 0.76 * max(0.08, min(eyeOpenness, 1)) * s
            for x in [46.0, 57.0] {
                let eye = CGRect(x: p(x - 3.4), y: p(50) - eyeHeight / 2, width: 6.8 * 0.76 * s, height: eyeHeight)
                context.fill(Path(ellipseIn: eye), with: .color(CarliColor.onBrand))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("carli")
        .accessibilityAddTraits(.isImage)
    }
}

#Preview {
    CarliLogo(size: 96)
}
