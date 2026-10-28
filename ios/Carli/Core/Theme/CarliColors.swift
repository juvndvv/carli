import SwiftUI
import UIKit

/// Neutral palette: the accent is ink (black in light, white in dark); lime is kept
/// for the brand mark, charts and rings. Each colour resolves
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
    static let positive = dynamic(0x0F7B4A, 0x10B981)
    static let warning = dynamic(0xB45309, 0xF59E0B)
    static let negative = dynamic(0xC8281C, 0xED5A46)
    static let dangerFill = Color(hex: 0xC8281C)

    /// Category slots c1–c8, all in lime tones so charts stay within the brand; neighbours alternate light and dark so slices stay apart.
    static let chart = [
        dynamic(0x4A6B00, 0xC6F432), dynamic(0xC9F04A, 0x6E9A00), dynamic(0x7AAE00, 0xE3FA9A), dynamic(0xDCF58C, 0x8BC400),
        dynamic(0x9ACD10, 0xD4FA45), dynamic(0x8C9C5A, 0x8C9C5A), dynamic(0xB2E600, 0xF0FDCB), dynamic(0x2C3F00, 0x4A6B00),
    ]
    /// The "Otras categorías" bucket.
    static let chartRest = dynamic(0xB9B9BE, 0x5A5A5E)
    /// Income bars: neutral ink, so only spending carries the accent.
    static let chartIncome = dynamic(0x1F1F1F, 0xFFFFFF)
    /// Spending bars and the net-worth line.
    static let chartAccent = dynamic(0x7AAE00, 0xC6F432)

    /// Activity rings, outer to inner: disponible, ahorro, ritmo. Lime tones: lime, green, teal.
    static let rings = [dynamic(0x8BC400, 0xC6F432), dynamic(0x22A447, 0x4ADE6B), dynamic(0x00A39A, 0x2EE6C5)]
    static let ringInk = [dynamic(0x4F7300, 0xC6F432), dynamic(0x167A33, 0x4ADE6B), dynamic(0x00756E, 0x2EE6C5)]

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
