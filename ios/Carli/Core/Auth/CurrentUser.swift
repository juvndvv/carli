import Foundation
import SwiftUI

enum ThemePreference: String, Codable, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct CurrentUser: Decodable, Equatable {
    struct Preferences: Decodable, Equatable {
        var theme: ThemePreference?
    }

    var id: String
    var name: String
    var email: String
    var twoFactorEnabled: Bool?
    var twoFactorPending: Bool?
    var preferences: Preferences?
    var createdAt: String?

    var theme: ThemePreference { preferences?.theme ?? .system }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}
