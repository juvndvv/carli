import SwiftUI
import UIKit

/// Neutral palette: the accent is ink (black in light, white in dark); lime is kept
/// for the brand mark, and sun amber for charts and rings. Each colour resolves
/// light/dark at render time, so views never branch on the colour scheme.
enum CarliColor {
    static let bg = dynamic(0xF2F2F7, 0x000000)
    static let surface = dynamic(0xFFFFFF, 0x1C1C1E)
    static let surface2 = dynamic(0xF0F0F2, 0x2C2C2E)
    static let border = dynamic(0xEBEBEB, 0x2C2C2E)
    static let text = dynamic(0x1F1F1F, 0xFFFFFF)
    static let text2 = dynamic(0x666666, 0xA3A3A3)
    static let text3 = dynamic(0x6E6E6E, 0x8A8A8A)
    static let primary = dynamic(0x1F1F1F, 0xFFFFFF)
    static let primarySoft = dynamic(0xF0F0F2, 0x2C2C2E)
    static let primaryStrong = dynamic(0x1F1F1F, 0xFFFFFF)
    static let onPrimary = dynamic(0xFFFFFF, 0x000000)
    static let brandInk = dynamic(0x1F1F1F, 0xFFFFFF)
    /// The carli mark: a lime gradient (brandLight on top, brand below) with a dark ink "c".
    static let brandLight = Color(hex: 0xD4FA45)
    static let brand = Color(hex: 0x9EE000)
    static let onBrand = Color(hex: 0x172300)
    /// Dark ink on sun-toned fills (rings, done habits).
    static let onSun = Color(hex: 0x1F1600)
    static let positive = dynamic(0x0F7B4A, 0x10B981)
    static let warning = dynamic(0xB45309, 0xF59E0B)
    static let negative = dynamic(0xC8281C, 0xED5A46)
    static let dangerFill = Color(hex: 0xC8281C)

    /// Category slots c1–c8, all in sun tones so charts stay within the brand; neighbours alternate light and dark so slices stay apart.
    static let chart = [
        dynamic(0x8A5A00, 0xFFC300), dynamic(0xFFC93D, 0xA86E00), dynamic(0xC27C00, 0xFFE08A), dynamic(0xF7D06A, 0xE09400),
        dynamic(0xE89A00, 0xFFD24D), dynamic(0xB8862E, 0xB8862E), dynamic(0xFFB000, 0xFFF0C2), dynamic(0x5C3B00, 0x8A5A00),
    ]
    /// The "Otras categorías" bucket.
    static let chartRest = dynamic(0xB9B9BE, 0x5A5A5E)
    /// Income bars: neutral ink, so only spending carries the accent.
    static let chartIncome = dynamic(0x1F1F1F, 0xFFFFFF)
    /// Spending bars and the net-worth line.
    static let chartAccent = dynamic(0xE89A00, 0xFFC300)

    /// Activity rings, outer to inner: disponible, ahorro, ritmo. Sunset tones: yellow, orange, coral.
    static let rings = [dynamic(0xF2A900, 0xFFD60A), dynamic(0xE07800, 0xFF9500), dynamic(0xE0482A, 0xFF6A3D)]
    static let ringInk = [dynamic(0x9A6200, 0xFFD60A), dynamic(0xA84F00, 0xFF9500), dynamic(0xB5361C, 0xFF6A3D)]

    nonisolated private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { @Sendable traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum CarliRadius {
    static let chip: CGFloat = 8
    static let control: CGFloat = 12
    static let controlLg: CGFloat = 16
    static let card: CGFloat = 22
    static let sheet: CGFloat = 28
}

enum CarliSpace {
    static let s4: CGFloat = 4, s8: CGFloat = 8, s12: CGFloat = 12, s16: CGFloat = 16
    static let s20: CGFloat = 20, s24: CGFloat = 24, s32: CGFloat = 32, s48: CGFloat = 48
}
