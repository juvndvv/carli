import Foundation

// MARK: Pending

/// One thing waiting for a decision, from any module (`GET v1/pending`).
struct PendingItem: Decodable, Identifiable, Equatable {
    var module: String
    var type: String
    var itemId: String
    var title: String
    var subtitle: String?
    var amountCents: Int?
    var date: String
    var route: String?
    var meta: [String: JSONValue]?

    var id: String { "\(module):\(type):\(itemId)" }

    enum CodingKeys: String, CodingKey {
        case module, type, itemId = "id", title, subtitle, amountCents, date, route, meta
    }

    /// The decoder camel-cases dictionary keys too, so `transaction_id` arrives as `transactionId`.
    func meta(_ key: String) -> String? {
        let parts = key.split(separator: "_")
        let camel = parts.prefix(1).joined() + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        switch meta?[camel] ?? meta?[key] {
        case .string(let value)? where !value.isEmpty: return value
        case .int(let value)?: return String(value)
        default: return nil
        }
    }

    /// "Hoy · Mercadona" like the Flutter row.
    var subtitleLine: String {
        let day = CarliDate.dayTitle(String(date.prefix(10)))
        return [day, subtitle ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct PendingPage: Decodable {
    struct Meta: Decodable {
        var hasMore: Bool?
        var nextCursor: String?
    }

    var data: [PendingItem]
    var meta: Meta?

    var nextCursor: String? { meta?.hasMore == true ? meta?.nextCursor : nil }
}

/// Label, symbol and money style for each pending type, as the Flutter registry has them.
struct PendingDescriptor {
    var label: String
    var symbol: String
    var neutralAmount = false

    static func of(_ module: String, _ type: String) -> PendingDescriptor {
        switch (module, type) {
        case ("finance", "transfer_suggestion"): PendingDescriptor(label: "Posibles transferencias", symbol: "arrow.left.arrow.right", neutralAmount: true)
        case ("finance", "uncategorized_transaction"): PendingDescriptor(label: "Movimientos por categorizar", symbol: "circle.dashed")
        case ("finance", "recurring_to_confirm"): PendingDescriptor(label: "Recurrentes por confirmar", symbol: "repeat")
        case ("tasks", "overdue_task"): PendingDescriptor(label: "Tareas vencidas", symbol: "checklist")
        default:
            PendingDescriptor(label: type.replacing(/[_.\-]+/, with: " ").trimmingCharacters(in: .whitespaces).capitalizedFirst,
                              symbol: "tray")
        }
    }

    static func moduleName(_ module: String) -> String {
        switch module {
        case "finance": "Finanzas"
        case "tasks": "Tareas"
        case "notes": "Notas"
        case "habits": "Hábitos"
        default: module
        }
    }

    static func moduleSymbol(_ module: String) -> String {
        switch module {
        case "finance": "creditcard"
        case "tasks": "checklist"
        default: "tray"
        }
    }
}

// MARK: Notifications

extension AppNotification {
    /// SF Symbol by notification type, mirroring the Flutter icon map.
    var symbol: String {
        let type = (type ?? "").lowercased()
        let map: [(String, String)] = [("budget", "exclamationmark.triangle"), ("recurring", "bell"), ("pending", "clock"),
                                       ("goal", "target"), ("debt", "banknote"), ("summary", "chart.bar"),
                                       ("period", "calendar"), ("upcoming", "repeat"), ("payroll", "wallet.bifold"),
                                       ("test", "bell")]
        return map.first { type.contains($0.0) }?.1 ?? "bell"
    }

    /// "Body · hace 5 minutos".
    var subtitleLine: String {
        let ago = createdAt.flatMap(CarliDate.instant).map { CarliDate.timeAgo($0) } ?? ""
        guard let body, !body.isEmpty else { return ago }
        return ago.isEmpty ? body : "\(body) · \(ago)"
    }
}

/// `{ "unread_count": n }`, returned by every notifications write.
struct UnreadCount: Decodable {
    var unreadCount: Int?
}

struct NotificationPreference: Decodable, Identifiable, Equatable {
    var type: String
    var label: String?
    var description: String?
    var push: Bool
    var inApp: Bool

    var id: String { type }
    var title: String {
        let text = label?.trimmingCharacters(in: .whitespaces) ?? ""
        return text.isEmpty ? (type.split(separator: ".").last.map(String.init) ?? type).replacingOccurrences(of: "_", with: " ") : text
    }
    var detail: String? {
        let text = description?.trimmingCharacters(in: .whitespaces) ?? ""
        return text.isEmpty ? nil : text
    }
}

struct NotificationPreferenceGroup: Decodable, Identifiable, Equatable {
    var module: String
    var name: String?
    var types: [NotificationPreference]

    var id: String { module }
}

// MARK: Search

struct SearchResult: Decodable, Identifiable, Equatable {
    var module: String?
    var moduleName: String?
    var type: String?
    var resultId: JSONValue?
    var title: String
    var subtitle: String?
    var url: String?
    var icon: String?

    enum CodingKeys: String, CodingKey {
        case module, moduleName, type, resultId = "id", title, subtitle, url, icon
    }

    var idString: String? {
        switch resultId {
        case .string(let value)?: value
        case .int(let value)?: String(value)
        default: nil
        }
    }

    var id: String { "\(module ?? ""):\(type ?? ""):\(idString ?? title):\(url ?? "")" }
}

// MARK: Security

struct TwoFactorSetup: Decodable {
    var qrCodeUrl: String
    var secretKey: String?
}

struct RecoveryCodes: Decodable {
    var recoveryCodes: [String]
}

struct AppToken: Decodable, Identifiable, Equatable {
    var id: Int
    var name: String
    var isCurrent: Bool?
    var lastUsedAt: String?
    var createdAt: String?

    var subtitle: String {
        guard let when = (lastUsedAt ?? createdAt).flatMap(CarliDate.instant) else { return "App de carli" }
        return "App de carli · \(CarliDate.timeAgo(when))"
    }
}

struct WebSession: Decodable, Identifiable, Equatable {
    var id: String
    var device: String?
    var isMobile: Bool?
    var isCurrent: Bool?
    var ipAddress: String?
    var lastActiveAt: String?

    var name: String { device ?? "Dispositivo desconocido" }
    var subtitle: String {
        let ago = lastActiveAt.flatMap(CarliDate.instant).map { CarliDate.timeAgo($0) } ?? ""
        return "\(ipAddress ?? "IP desconocida") · \(ago)"
    }
}

extension CarliDate {
    /// "ahora", "hace 5 minutos", "ayer", "hace 3 días" or a short date, like the Flutter inbox.
    static func timeAgo(_ instant: Date, now: Date = .now) -> String {
        let seconds = Int((instant.timeIntervalSince(now)).rounded())
        let absolute = abs(seconds)
        func relative(_ amount: Int, _ one: String, _ many: String) -> String {
            let unit = abs(amount) == 1 ? one : many
            return amount < 0 ? "hace \(-amount) \(unit)" : "dentro de \(amount) \(unit)"
        }
        if absolute < 60 { return "ahora" }
        if absolute < 3600 { return relative(Int((Double(seconds) / 60).rounded()), "minuto", "minutos") }
        if absolute < 86_400 { return relative(Int((Double(seconds) / 3600).rounded()), "hora", "horas") }
        if absolute < 7 * 86_400 {
            let days = Int((Double(seconds) / 86_400).rounded())
            switch days {
            case -2: return "anteayer"
            case -1: return "ayer"
            case 1: return "mañana"
            case 2: return "pasado mañana"
            default: return relative(days, "día", "días")
            }
        }
        return short(instant)
    }
}
