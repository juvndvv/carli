import SwiftUI

/// SF Pro everywhere through the system text styles (so Dynamic Type works);
/// Geist only for the "carli" wordmark.
extension Font {
    static func carliWordmark(_ size: CGFloat) -> Font {
        .custom("Geist", fixedSize: size).weight(.semibold)
    }
}

extension View {
    func carliWordmark(_ size: CGFloat) -> some View {
        font(.carliWordmark(size)).tracking(-0.03 * size)
    }
}
