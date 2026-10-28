import SwiftUI

/// The carli face: a sun rounded square with two dark eyes. `eyeOpenness`
/// drives the launch blink (1 open, 0 closed).
struct CarliLogo: View {
    var size: CGFloat = 30
    var eyeOpenness: CGFloat = 1

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100
            let face = Path(roundedRect: CGRect(x: 12 * s, y: 12 * s, width: 76 * s, height: 76 * s),
                            cornerRadius: 28 * s, style: .continuous)
            context.fill(face, with: .color(CarliColor.brand))
            let eyeHeight = 18 * max(0.08, min(eyeOpenness, 1)) * s
            for x in [39.0, 61.0] {
                let eye = CGRect(x: (x - 5.5) * s, y: 47 * s - eyeHeight / 2, width: 11 * s, height: eyeHeight)
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
