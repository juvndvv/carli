import SwiftUI
import UIKit

/// Sun palette (amber accent on neutral greys). Each colour resolves
/// light/dark at render time, so views never branch on the colour scheme.
enum CarliColor {
    static let bg = dynamic(0xF2F2F7, 0x000000)
    static let surface = dynamic(0xFFFFFF, 0x1C1C1E)
    static let surface2 = dynamic(0xF0F0F2, 0x2C2C2E)
    static let border = dynamic(0xEBEBEB, 0x2C2C2E)
    static let text = dynamic(0x1F1F1F, 0xFFFFFF)
    static let text2 = dynamic(0x666666, 0xA3A3A3)
    static let text3 = dynamic(0x6E6E6E, 0x8A8A8A)
    static let primary = dynamic(0xF2A900, 0xFFC300)
    static let primarySoft = dynamic(0xFFF4D6, 0x3A2C00)
    static let primaryStrong = dynamic(0xE89A00, 0xFFC300)
    /// Ink on sun fills: white fails contrast on yellow.
    static let onPrimary = Color(hex: 0x1F1600)
    /// Accent for text; the fill colour is too light to read on white.
    static let brandInk = dynamic(0x9A6200, 0xFFD24D)
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

    /// Activity rings, outer to inner: disponible, ahorro, ritmo.
    static let rings = [dynamic(0xF2A900, 0xFFC300), dynamic(0x3D9C0E, 0xA6FF00), dynamic(0x0091B3, 0x00F0FF)]
    static let ringInk = [dynamic(0x9A6200, 0xFFD24D), dynamic(0x2E7D0C, 0xA6FF00), dynamic(0x007E9C, 0x00F0FF)]

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
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
    convenience init(hex: UInt32) {
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
