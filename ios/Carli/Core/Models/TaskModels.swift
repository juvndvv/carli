import Foundation

extension Notification.Name {
    /// Posted after any task, list or template write so every Tareas screen reloads.
    static let tasksChanged = Notification.Name("carli.tasksChanged")
}

struct TaskListRef: Decodable, Equatable, Hashable {
    var id: String
    var name: String
    var color: String?
    var isDefault: Bool?
}

struct TaskList: Decodable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var icon: String?
    var color: String?
    var isDefault: Bool?
    var archived: Bool?
    var openTasksCount: Int?

    var isInbox: Bool { isDefault == true }
    var openCount: Int { openTasksCount ?? 0 }
    var symbol: String { icon.map(CarliIcon.symbol) ?? (isInbox ? "tray" : "list.bullet") }
}

struct Subtask: Decodable, Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var done: Bool
}

struct TaskTemplateRef: Decodable, Equatable, Hashable {
    var id: String
    var title: String?
    var frequencyText: String?
    var paused: Bool?
}

struct TaskOccurrence: Decodable, Identifiable, Equatable {
    var templateId: String
    var date: String
    var title: String
    var list: TaskListRef
    var frequencyText: String?
    var dueTime: String?
    var important: Bool?

    var id: String { "\(templateId)-\(date)" }
}

struct UpcomingDay: Decodable, Identifiable, Equatable {
    var date: String
    var tasks: [TaskItem]
    var occurrences: [TaskOccurrence]

    var id: String { date }
    var isEmpty: Bool { tasks.isEmpty && occurrences.isEmpty }
}

enum TemplatePolicy: String, CaseIterable, Identifiable {
    case replace, accumulate

    var id: String { rawValue }
    var label: String { self == .replace ? "Sustituir" : "Acumular" }
    var hint: String {
        self == .replace ? "La anterior queda como omitida y solo hay una abierta" : "Se quedan todas abiertas hasta que las hagas"
    }
}

struct TaskTemplate: Decodable, Identifiable, Equatable {
    var id: String
    var title: String
    var notes: String?
    var list: TaskListRef
    var subtasks: [String]?
    var rrule: String?
    var afterDoneIntervalDays: Int?
    var dtstart: String
    var until: String?
    var count: Int?
    var policy: String?
    var leadDays: Int?
    var dueTime: String?
    var important: Bool?
    var paused: Bool?
    var frequencyText: String?
    var endingText: String?
    var nextDate: String?
    var openTaskId: String?
    var upcomingDates: [String]?
    var skippedDates: [String]?

    var isPaused: Bool { paused == true }
    var afterDone: Bool { afterDoneIntervalDays != nil }

    var rule: String {
        var parts = [frequencyText ?? ""]
        if let dueTime { parts.append(dueTime) }
        let lead = leadDays ?? 0
        if lead > 0 { parts.append(lead == 1 ? "aparece 1 día antes" : "aparece \(lead) días antes") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct TemplateHistory: Decodable, Equatable {
    struct Entry: Decodable, Equatable, Identifiable {
        var taskId: String
        var date: String
        var status: String?
        var skipReason: String?
        var id: String { taskId }

        var label: String {
            switch (status, skipReason) {
            case ("done", _): "Hecha"
            case ("open", _): "Abierta"
            case (_, "manual"): "Saltada"
            case (_, "replaced"): "Sustituida"
            default: "No hecha"
            }
        }
    }

    var items: [Entry]
    var done: Int
    var window: Int

    var streakLabel: String? { window == 0 ? nil : "Hecha \(done) de las últimas \(window)" }
}

struct FrequencyPreview: Decodable, Equatable {
    var description: String?
    var ending: String?
    var dates: [String]
}

struct TasksSettings: Decodable, Equatable {
    var defaultListId: String?
    var defaultPolicy: String?
    var showDoneInToday: Bool?

    var policy: TemplatePolicy { TemplatePolicy(rawValue: defaultPolicy ?? "") ?? .replace }
    var showsDone: Bool { showDoneInToday ?? true }
}

/// Builds and parses the RRULE subset the template editor offers.
struct FrequencyDraft: Equatable {
    enum Unit: String, CaseIterable, Identifiable {
        case daily = "DAILY", weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .daily: "Diaria"
            case .weekly: "Semanal"
            case .monthly: "Mensual"
            case .yearly: "Anual"
            }
        }
    }

    enum MonthlyMode: String, CaseIterable, Identifiable {
        case dayOfMonth, lastDay, weekdayPosition
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dayOfMonth: "Día del mes"
            case .lastDay: "Último día"
            case .weekdayPosition: "Día de semana"
            }
        }
    }

    static let weekdayCodes = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
    static let positions: [(Int, String)] = [(1, "Primer"), (2, "Segundo"), (3, "Tercer"), (4, "Cuarto"), (-1, "Último")]

    var afterDone = false
    var unit: Unit = .weekly
    var interval = 1
    /// ISO weekdays, Monday = 1.
    var weekdays: Set<Int> = [1]
    var monthlyMode: MonthlyMode = .dayOfMonth
    var monthDay = 1
    var position = 1
    var positionWeekday = 1
    var yearMonth = 1
    var afterDoneDays = 7

    static func isoWeekday(_ date: Date) -> Int {
        let weekday = CarliDate.calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    static func initial(_ start: Date) -> FrequencyDraft {
        let parts = CarliDate.calendar.dateComponents([.day, .month], from: start)
        var draft = FrequencyDraft()
        draft.weekdays = [isoWeekday(start)]
        draft.monthDay = parts.day ?? 1
        draft.positionWeekday = isoWeekday(start)
        draft.yearMonth = parts.month ?? 1
        return draft
    }

    static func parse(rrule: String?, afterDoneDays: Int?, start: Date) -> FrequencyDraft {
        var draft = initial(start)
        if let afterDoneDays {
            draft.afterDone = true
            draft.afterDoneDays = afterDoneDays
            return draft
        }
        guard let rrule, !rrule.isEmpty else { return draft }
        var parts: [String: String] = [:]
        for segment in rrule.split(separator: ";") {
            let pair = segment.split(separator: "=", maxSplits: 1).map { String($0).uppercased() }
            if pair.count == 2 { parts[pair[0]] = pair[1] }
        }
        draft.unit = Unit(rawValue: parts["FREQ"] ?? "") ?? .weekly
        draft.interval = Int(parts["INTERVAL"] ?? "") ?? 1
        let byDay = (parts["BYDAY"] ?? "").split(separator: ",").map(String.init).filter { !$0.isEmpty }
        let days = Set(byDay.compactMap { code in weekdayCodes.firstIndex(of: String(code.suffix(2))).map { $0 + 1 } })
        let monthDay = Int(parts["BYMONTHDAY"] ?? "")
        let position = Int(parts["BYSETPOS"] ?? "")
            ?? (byDay.count == 1 && byDay[0].count > 2 ? Int(byDay[0].dropLast(2)) : nil)
        if draft.unit == .weekly, !days.isEmpty { draft.weekdays = days }
        if draft.unit == .monthly {
            if monthDay == -1 {
                draft.monthlyMode = .lastDay
            } else if monthDay == nil, position != nil, days.count == 1 {
                draft.monthlyMode = .weekdayPosition
            }
        }
        if let monthDay, monthDay > 0 { draft.monthDay = monthDay }
        if let position { draft.position = position }
        if days.count == 1, let day = days.first { draft.positionWeekday = day }
        if let month = Int(parts["BYMONTH"] ?? "") { draft.yearMonth = month }
        return draft
    }

    var rrule: String? {
        guard !afterDone else { return nil }
        var parts = ["FREQ=\(unit.rawValue)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        switch unit {
        case .daily: break
        case .weekly: parts.append("BYDAY=\(weekdays.sorted().map { Self.weekdayCodes[$0 - 1] }.joined(separator: ","))")
        case .monthly:
            switch monthlyMode {
            case .dayOfMonth: parts.append("BYMONTHDAY=\(monthDay)")
            case .lastDay: parts.append("BYMONTHDAY=-1")
            case .weekdayPosition: parts += ["BYDAY=\(Self.weekdayCodes[positionWeekday - 1])", "BYSETPOS=\(position)"]
            }
        case .yearly: parts += ["BYMONTH=\(yearMonth)", "BYMONTHDAY=\(monthDay)"]
        }
        return parts.joined(separator: ";")
    }

    var fields: [String: JSONValue] {
        afterDone ? ["after_done_interval_days": .int(afterDoneDays), "rrule": .null]
            : ["rrule": .optional(rrule), "after_done_interval_days": .null]
    }

    var intervalLabel: String {
        switch unit {
        case .daily: interval == 1 ? "Cada día" : "Cada \(interval) días"
        case .weekly: interval == 1 ? "Cada semana" : "Cada \(interval) semanas"
        case .monthly: interval == 1 ? "Cada mes" : "Cada \(interval) meses"
        case .yearly: interval == 1 ? "Cada año" : "Cada \(interval) años"
        }
    }

    mutating func toggle(_ day: Int) {
        if weekdays.contains(day) {
            if weekdays.count > 1 { weekdays.remove(day) }
        } else {
            weekdays.insert(day)
        }
    }
}

enum QuickDate: String, CaseIterable, Identifiable {
    case today, tomorrow, weekend, nextWeek, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "Hoy"
        case .tomorrow: "Mañana"
        case .weekend: "Fin de semana"
        case .nextWeek: "Próxima semana"
        case .none: "Sin fecha"
        }
    }

    func resolve(_ now: Date = .now) -> Date? {
        let calendar = CarliDate.calendar
        let today = calendar.startOfDay(for: now)
        let weekday = FrequencyDraft.isoWeekday(today)
        func add(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: today) ?? today }
        switch self {
        case .today: return today
        case .tomorrow: return add(1)
        case .weekend: return add(weekday >= 6 ? 7 - weekday + 6 : 6 - weekday)
        case .nextWeek: return add(8 - weekday)
        case .none: return nil
        }
    }

    static func of(_ date: Date?) -> QuickDate? {
        let day = date.map { CarliDate.calendar.startOfDay(for: $0) }
        return allCases.first { $0.resolve() == day }
    }
}

enum TaskDates {
    static let weekdaysMondayFirst = ["L", "M", "X", "J", "V", "S", "D"]
    static let weekdaysLongMondayFirst = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]

    static func offset(_ date: Date, now: Date = .now) -> Int {
        let calendar = CarliDate.calendar
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// "Hoy", "Mañana", "Hace 3 días", "Jueves", "12 nov".
    static func dueLabel(_ date: Date, now: Date = .now) -> String {
        let days = offset(date, now: now)
        switch days {
        case 0: return "Hoy"
        case 1: return "Mañana"
        case -1: return "Ayer"
        case ..<(-1): return "Hace \(-days) días"
        case ..<7: return weekdaysLongMondayFirst[FrequencyDraft.isoWeekday(date) - 1].capitalizedFirst
        default:
            let sameYear = CarliDate.calendar.component(.year, from: date) == CarliDate.calendar.component(.year, from: now)
            return sameYear ? CarliDate.short(date) : "\(CarliDate.short(date)) \(CarliDate.calendar.component(.year, from: date))"
        }
    }

    /// "jue 12 nov".
    static func weekdayShort(_ date: Date) -> String {
        "\(weekdaysLongMondayFirst[FrequencyDraft.isoWeekday(date) - 1].prefix(3)) \(CarliDate.short(date))"
    }

    static func distance(_ date: Date) -> String {
        switch offset(date) {
        case 0: "hoy"
        case 1: "mañana"
        case let days: "en \(days) días"
        }
    }

    static func time(_ date: Date) -> String {
        let parts = CarliDate.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    static func date(fromTime value: String?) -> Date {
        let parts = (value ?? "09:00").split(separator: ":").compactMap { Int($0) }
        return CarliDate.calendar.date(bySettingHour: parts.first ?? 9, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: .now) ?? .now
    }
}
