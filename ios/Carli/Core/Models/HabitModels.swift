import Foundation

extension Notification.Name {
    /// Posted after any habit write so Hoy, the list, the detail, Inicio and Tareas reload.
    static let habitsChanged = Notification.Name("carli.habitsChanged")
}

enum HabitKind: String, CaseIterable, Identifiable {
    case check, quantity, avoid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .check: "Sí / No"
        case .quantity: "Cantidad"
        case .avoid: "Evitar"
        }
    }

    static func of(_ value: String?) -> HabitKind { value.flatMap(HabitKind.init(rawValue:)) ?? .check }
}

enum HabitStatus: String {
    case active, paused, archived

    static func of(_ value: String?) -> HabitStatus { value.flatMap(HabitStatus.init(rawValue:)) ?? .active }
}

/// How a single day looks in the week dots, the calendar and the progress grid.
enum DayState: String, Decodable {
    case done, miss, today, future, off, rest, none

    init(from decoder: Decoder) throws {
        self = DayState(rawValue: (try? decoder.singleValueContainer().decode(String.self)) ?? "") ?? .none
    }

    var label: String {
        switch self {
        case .done: "cumplido"
        case .miss: "no cumplido"
        case .today: "hoy, pendiente"
        case .future: "por llegar"
        case .off: "no toca"
        case .rest: "descanso"
        case .none: "sin empezar"
        }
    }
}

/// Snake-case keys shared by every habit payload; decoding is lenient so partial payloads still load.
private enum HabitKeys: String, CodingKey {
    case id, name, icon, kind, unit, showInTasks, sort, startDate, preferredTime, status, convertedFromTemplateId, goal, goalText
}

struct HabitGoal: Decodable, Hashable {
    var period: String
    var target: Double
    var daysOfWeek: [Int]?
    var validFrom: String?

    var weekly: Bool { period == "week" }

    private enum CodingKeys: String, CodingKey { case period, target, daysOfWeek, validFrom }

    init(period: String = "day", target: Double = 1, daysOfWeek: [Int]? = nil, validFrom: String? = nil) {
        self.period = period
        self.target = target
        self.daysOfWeek = daysOfWeek
        self.validFrom = validFrom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        period = try c.decodeIfPresent(String.self, forKey: .period) ?? "day"
        target = try c.decodeIfPresent(Double.self, forKey: .target) ?? 0
        daysOfWeek = try c.decodeIfPresent([Int].self, forKey: .daysOfWeek)
        validFrom = try c.decodeIfPresent(String.self, forKey: .validFrom)
    }
}

struct Habit: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String
    var kindRaw: String
    var unit: String?
    var showInTasks: Bool
    var sort: Int
    var startDate: String
    var preferredTime: String?
    var statusRaw: String?
    var convertedFromTemplateId: String?
    var goal: HabitGoal
    var goalText: String

    var kind: HabitKind { .of(kindRaw) }
    var status: HabitStatus { .of(statusRaw) }
    var isAvoid: Bool { kind == .avoid }
    var start: Date { CarliDate.day(startDate) ?? .now }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: HabitKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "check"
        kindRaw = try c.decodeIfPresent(String.self, forKey: .kind) ?? "check"
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        showInTasks = try c.decodeIfPresent(Bool.self, forKey: .showInTasks) ?? true
        sort = try c.decodeIfPresent(Int.self, forKey: .sort) ?? 0
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate) ?? CarliDate.isoDay(.now)
        preferredTime = try c.decodeIfPresent(String.self, forKey: .preferredTime)
        statusRaw = try c.decodeIfPresent(String.self, forKey: .status)
        convertedFromTemplateId = try c.decodeIfPresent(String.self, forKey: .convertedFromTemplateId)
        goal = try c.decodeIfPresent(HabitGoal.self, forKey: .goal) ?? HabitGoal()
        goalText = try c.decodeIfPresent(String.self, forKey: .goalText) ?? ""
    }
}

struct DayCell: Decodable, Hashable {
    var date: String
    var state: DayState
}

struct HabitListItem: Decodable, Identifiable, Hashable {
    var habit: Habit
    var consistency: Int?
    var streak: Int
    var week: [DayCell]

    var id: String { habit.id }

    private enum CodingKeys: String, CodingKey { case consistency, streak, week }

    init(from decoder: Decoder) throws {
        habit = try Habit(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        consistency = try c.decodeIfPresent(Int.self, forKey: .consistency)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        week = try c.decodeIfPresent([DayCell].self, forKey: .week) ?? []
    }
}

struct WeekBar: Decodable, Hashable {
    var start: String
    var value: Double
    var target: Double
}

struct HabitDetail: Decodable {
    struct Stats: Decodable {
        var consistency: Int?
        var consistencyAll: Int?
        var streak: Int?
        var bestStreak: Int?
        var bestStreakEnd: String?
    }

    var habit: Habit
    var stats: Stats
    var goals: [HabitGoal]
    var weeks: [WeekBar]
    var today: HabitToday?

    private enum CodingKeys: String, CodingKey { case stats, goals, weeks, today }

    init(from decoder: Decoder) throws {
        habit = try Habit(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats = try c.decodeIfPresent(Stats.self, forKey: .stats) ?? Stats()
        goals = try c.decodeIfPresent([HabitGoal].self, forKey: .goals) ?? []
        weeks = try c.decodeIfPresent([WeekBar].self, forKey: .weeks) ?? []
        today = try? c.decodeIfPresent(HabitToday.self, forKey: .today)
    }
}

struct CalendarDay: Decodable, Hashable, Identifiable {
    var date: String
    var state: DayState
    var value: Double
    var note: String?

    var id: String { date }

    private enum CodingKeys: String, CodingKey { case date, state, value, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        state = try c.decodeIfPresent(DayState.self, forKey: .state) ?? .none
        value = try c.decodeIfPresent(Double.self, forKey: .value) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

struct HabitCalendar: Decodable {
    var days: [CalendarDay]
}

enum ProgressRange: String, CaseIterable, Identifiable {
    case week, month, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "Semana"
        case .month: "Mes"
        case .year: "Año"
        }
    }

    var previous: String {
        switch self {
        case .week: "la semana anterior"
        case .month: "el mes anterior"
        case .year: "el año anterior"
        }
    }
}

struct ProgressRow: Decodable, Identifiable {
    var id: String
    var name: String
    var icon: String
    var consistency: Int?
    var trend: Int?
    var met: Int
    var total: Int
    /// Day cells for week and month; month consistencies for year.
    var cells: [DayCell]
    var monthCells: [Int?]

    private enum CodingKeys: String, CodingKey { case id, name, icon, consistency, trend, met, total, cells }
    private struct MonthCell: Decodable { var month: String?; var consistency: Int? }
    private struct AnyCell: Decodable {
        var date: String?
        var state: DayState?
        var month: String?
        var consistency: Int?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "check"
        consistency = try c.decodeIfPresent(Int.self, forKey: .consistency)
        trend = try c.decodeIfPresent(Int.self, forKey: .trend)
        met = try c.decodeIfPresent(Int.self, forKey: .met) ?? 0
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        let raw = try c.decodeIfPresent([AnyCell].self, forKey: .cells) ?? []
        if raw.first?.month != nil {
            cells = []
            monthCells = raw.map(\.consistency)
        } else {
            cells = raw.map { DayCell(date: $0.date ?? "", state: $0.state ?? .none) }
            monthCells = []
        }
    }
}

struct HabitsProgress: Decodable {
    var range: String
    var from: String
    var to: String
    var consistency: Int?
    var previousConsistency: Int?
    var trend: Int?
    var met: Int?
    var total: Int?
    var habits: [ProgressRow]

    var kind: ProgressRange { ProgressRange(rawValue: range) ?? .week }
}

struct HabitBreak: Decodable, Identifiable, Hashable {
    var id: String
    var habitId: String?
    var fromDate: String
    var toDate: String
    var active: Bool?
    var upcoming: Bool?

    var global: Bool { habitId == nil }
    var isActive: Bool { active == true }
    var isUpcoming: Bool { upcoming == true }

    /// "27 oct" or "27 oct – 2 nov".
    var range: String {
        let from = CarliDate.day(fromDate).map(CarliDate.short) ?? fromDate
        let to = CarliDate.day(toDate).map(CarliDate.short) ?? toDate
        return fromDate == toDate ? from : "\(from) – \(to)"
    }
}

struct ConversionPreview: Decodable {
    var templateId: String
    var name: String?
    var goalText: String?
    var done: Int?
    var skipped: Int?
    var missed: Int?
    var consistency: Int?
    var streak: Int?
    var cells: [DayCell]?
}

struct HabitsSettings: Decodable {
    var showInTasks: Bool?
    var digest: Bool?
}
