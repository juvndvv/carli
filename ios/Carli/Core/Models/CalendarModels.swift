import SwiftUI

extension Notification.Name {
    /// Posted after a Google account or calendar changes, so the calendar reloads.
    static let calendarChanged = Notification.Name("carli.calendarChanged")
}

/// Where an item comes from; each one is a filter in the calendar.
enum CalendarSource: String, CaseIterable, Identifiable {
    case google, tasks, templates, finance, health, habits

    var id: String { rawValue }

    var label: String {
        switch self {
        case .google: "Google Calendar"
        case .tasks: "Tareas"
        case .templates: "Tareas programadas"
        case .finance: "Cargos previstos"
        case .health: "Salud"
        case .habits: "Hábitos"
        }
    }

    var symbol: String {
        switch self {
        case .google: "calendar"
        case .tasks: "checkmark.circle"
        case .templates: "repeat"
        case .finance: "eurosign.circle"
        case .health: "scalemass"
        case .habits: "circle.dashed"
        }
    }
}

/// The few `meta` fields the app reads; the server sends more or fewer per source.
struct CalendarMeta: Decodable, Equatable {
    var eventId: String?
    var calendar: String?
    var account: String?
    var location: String?
    var description: String?
    var htmlLink: String?
    var meetLink: String?
    var startsAt: String?
    var endsAt: String?
    var startDate: String?
    var lastDate: String?
    var allDay: Bool?
    var taskId: String?
    var templateId: String?
    var important: Bool?
    var overdue: Bool?
    var ruleId: String?
    var kind: String?
    var amountCents: Int?
    var subscription: Bool?
    var done: Int?
    var total: Int?
}

struct CalendarItem: Decodable, Identifiable, Equatable {
    var source: String
    var id: String
    var title: String
    var date: String
    var time: String?
    var endTime: String?
    var allDay: Bool
    var done: Bool
    var subtitle: String?
    var color: String?
    var url: String?
    var meta: CalendarMeta?

    var kind: CalendarSource? { CalendarSource(rawValue: source) }
    /// Unique across sources (a task id and an event id never clash, but be safe).
    var key: String { "\(source):\(id)" }

    /// "09:30 – 10:15", "09:30" or nil for all-day items.
    var timeRange: String? {
        guard let time else { return nil }
        guard let endTime, endTime != time else { return time }
        return "\(time) – \(endTime)"
    }

    /// The Google calendar's own colour, if any.
    var tint: Color? {
        guard let color, color.hasPrefix("#"), let hex = UInt32(color.dropFirst(), radix: 16) else { return nil }
        return Color(hex: hex)
    }
}

struct GoogleStatus: Decodable, Equatable {
    var accounts: Int
    var reconnect: [String]
    var syncedAt: String?
}

struct CalendarRange: Decodable, Equatable {
    var from: String
    var to: String
    var items: [CalendarItem]
    var google: GoogleStatus
}

struct GoogleCalendarRef: Decodable, Identifiable, Equatable {
    var id: String
    var name: String
    var color: String?
    var primary: Bool
    var selected: Bool

    var tint: Color? {
        guard let color, color.hasPrefix("#"), let hex = UInt32(color.dropFirst(), radix: 16) else { return nil }
        return Color(hex: hex)
    }
}

struct GoogleAccount: Decodable, Identifiable, Equatable {
    var id: String
    var email: String
    var status: String
    var syncedAt: String?
    var lastError: String?
    var calendars: [GoogleCalendarRef]

    var needsReconnect: Bool { status == "reconnect" }
}

struct GoogleAccounts: Decodable, Equatable {
    var configured: Bool
    var accounts: [GoogleAccount]
}

struct GoogleAuthURL: Decodable {
    var authUrl: String
}
