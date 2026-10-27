import SwiftUI
import UIKit

/// Ember palette, ported from the Flutter `CarliColors` tokens. Each colour resolves
/// light/dark at render time, so views never branch on the colour scheme.
enum CarliColor {
    static let bg = dynamic(0xF2F2F7, 0x000000)
    static let surface = dynamic(0xFFFFFF, 0x1C1C1E)
    static let surface2 = dynamic(0xF0F0F2, 0x2C2C2E)
    static let border = dynamic(0xEBEBEB, 0x2C2C2E)
    static let text = dynamic(0x1F1F1F, 0xFFFFFF)
    static let text2 = dynamic(0x666666, 0xA3A3A3)
    static let text3 = dynamic(0x6E6E6E, 0x8A8A8A)
    static let primary = dynamic(0xE5063F, 0xE5063F)
    static let primarySoft = dynamic(0xFFEBF0, 0x3A0A18)
    static let primaryStrong = dynamic(0xE5063F, 0xFA114F)
    static let onPrimary = Color.white
    static let brandInk = dynamic(0xD90033, 0xFF5C85)
    static let positive = dynamic(0x0F7B4A, 0x10B981)
    static let warning = dynamic(0xB45309, 0xF59E0B)
    static let negative = dynamic(0xC8281C, 0xED5A46)
    static let dangerFill = Color(hex: 0xC8281C)

    /// Validated categorical chart palette, slots c1…c8.
    static let chart = [
        dynamic(0x2A78D6, 0x3987E5), dynamic(0xEB6834, 0xD95926), dynamic(0x1BAF7A, 0x199E70), dynamic(0xEDA100, 0xC98500),
        dynamic(0xE87BA4, 0xD55181), dynamic(0x008300, 0x008300), dynamic(0x6250D6, 0x9085E9), dynamic(0xE34948, 0xE66767),
    ]

    /// Activity rings, outer to inner: disponible, ahorro, ritmo.
    static let rings = [dynamic(0xE5063F, 0xFA114F), dynamic(0x3D9C0E, 0xA6FF00), dynamic(0x0091B3, 0x00F0FF)]
    static let ringInk = [dynamic(0xD90033, 0xFF5C85), dynamic(0x2E7D0C, 0xA6FF00), dynamic(0x007E9C, 0x00F0FF)]

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
