import Foundation

/// How the calendar is laid out, like Google Calendar on the phone. Remembered between visits.
enum CalendarMode: String, CaseIterable, Identifiable {
    case agenda, day, threeDays, week, month, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .agenda: "Agenda"
        case .day: "Día"
        case .threeDays: "3 días"
        case .week: "Semana"
        case .month: "Mes"
        case .year: "Año"
        }
    }

    var symbol: String {
        switch self {
        case .agenda: "list.bullet"
        case .day: "rectangle"
        case .threeDays: "rectangle.split.3x1"
        case .week: "rectangle.split.3x3"
        case .month: "calendar"
        case .year: "square.grid.3x3"
        }
    }

    /// Columns of the hour grid, for the modes that have one.
    var columns: Int? {
        switch self {
        case .day: 1
        case .threeDays: 3
        case .week: 7
        default: nil
        }
    }
}

/// Date maths and the hour-grid layout, kept apart from the views so they can be tested.
enum CalendarLayout {
    static var calendar: Calendar { CarliDate.calendar }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func add(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func monday(of date: Date) -> Date {
        let day = startOfDay(date)
        return add(days: -(FrequencyDraft.isoWeekday(day) - 1), to: day)
    }

    static func firstOfMonth(_ date: Date) -> Date {
        let c = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: c) ?? startOfDay(date)
    }

    static func firstOfYear(_ date: Date) -> Date {
        let c = calendar.dateComponents([.year], from: date)
        return calendar.date(from: c) ?? startOfDay(date)
    }

    /// "2026-11": the cache key for a month of items.
    static func monthKey(_ date: Date) -> String { String(CarliDate.isoDay(date).prefix(7)) }

    /// First and last day of the month a key names.
    static func bounds(ofMonth key: String) -> (from: Date, to: Date)? {
        guard let first = CarliDate.day("\(key)-01"),
              let next = calendar.date(byAdding: .month, value: 1, to: first) else { return nil }
        return (first, add(days: -1, to: next))
    }

    /// The days a mode shows around the selected day: the day itself, three days from it,
    /// its Monday-first week, or the whole weeks that cover its month.
    static func days(_ mode: CalendarMode, around selected: Date) -> [Date] {
        let day = startOfDay(selected)
        switch mode {
        case .day:
            return [day]
        case .threeDays:
            return (0..<3).map { add(days: $0, to: day) }
        case .week:
            let start = monday(of: day)
            return (0..<7).map { add(days: $0, to: start) }
        case .month:
            let first = firstOfMonth(day)
            let start = monday(of: first)
            let last = bounds(ofMonth: monthKey(first))?.to ?? first
            let count = (calendar.dateComponents([.day], from: start, to: last).day ?? 27) + 1
            let weeks = Int((Double(count) / 7).rounded(.up))
            return (0..<(weeks * 7)).map { add(days: $0, to: start) }
        case .agenda, .year:
            return [day]
        }
    }

    /// Months whose items are needed to draw these days.
    static func monthKeys(for days: [Date]) -> [String] {
        var keys: [String] = []
        for day in days {
            let key = monthKey(day)
            if !keys.contains(key) { keys.append(key) }
        }
        return keys
    }

    /// The selected day moved one page forward or back.
    static func step(_ mode: CalendarMode, from selected: Date, by direction: Int) -> Date {
        switch mode {
        case .day: add(days: direction, to: selected)
        case .threeDays: add(days: 3 * direction, to: selected)
        case .week: add(days: 7 * direction, to: selected)
        case .month, .agenda: calendar.date(byAdding: .month, value: direction, to: firstOfMonth(selected)) ?? selected
        case .year: calendar.date(byAdding: .year, value: direction, to: firstOfYear(selected)) ?? selected
        }
    }

    /// "Noviembre", "Noviembre 2027", "Oct – nov" or "2026".
    static func title(_ mode: CalendarMode, selected: Date, now: Date = .now) -> String {
        let thisYear = calendar.component(.year, from: now)
        if mode == .year { return "\(calendar.component(.year, from: selected))" }
        let days = days(mode, around: selected)
        let first = mode == .month ? firstOfMonth(selected) : (days.first ?? selected)
        let last = mode == .month ? first : (days.last ?? selected)
        let a = calendar.dateComponents([.month, .year], from: first)
        let b = calendar.dateComponents([.month, .year], from: last)
        let year = b.year ?? thisYear
        let suffix = year == thisYear ? "" : " \(year)"
        if a.month == b.month {
            return CarliDate.months[(a.month ?? 1) - 1].capitalizedFirst + suffix
        }
        let from = CarliDate.monthsShort[(a.month ?? 1) - 1].capitalizedFirst
        let to = CarliDate.monthsShort[(b.month ?? 1) - 1]
        return "\(from) – \(to)\(suffix)"
    }

    // MARK: Hour grid

    /// Minutes since midnight of "HH:MM".
    static func minutes(_ time: String?) -> Int? {
        guard let time else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// One timed item placed in a day column: where it starts and ends, and which of the
    /// side-by-side lanes it takes when it overlaps others.
    struct Placed: Equatable {
        var item: CalendarItem
        var start: Int
        var end: Int
        var lane: Int
        var lanes: Int
    }

    /// Items without an end last half an hour on the grid; a timed event that runs past
    /// midnight fills the rest of its first day.
    static let defaultLength = 30

    static func place(_ items: [CalendarItem]) -> [Placed] {
        let timed: [(item: CalendarItem, start: Int, end: Int)] = items.compactMap { item in
            guard !item.allDay, let start = minutes(item.time) else { return nil }
            var end = minutes(item.endTime) ?? start + defaultLength
            if item.endTime == nil, item.meta?.lastDate != nil, item.meta?.lastDate != item.meta?.startDate {
                end = 24 * 60
            }
            if end <= start { end = start + defaultLength }
            return (item, start, min(end, 24 * 60))
        }
        .sorted { ($0.start, -$0.end, $0.item.title) < ($1.start, -$1.end, $1.item.title) }

        var placed: [Placed] = []
        var group: [Placed] = []
        var laneEnds: [Int] = []
        var groupEnd = -1

        func close() {
            let lanes = max(laneEnds.count, 1)
            placed += group.map { var p = $0; p.lanes = lanes; return p }
            group = []
            laneEnds = []
        }

        for entry in timed {
            if entry.start >= groupEnd { close() }
            // Blocks shorter than the default still take its height, so lanes use the visual end.
            let visualEnd = max(entry.end, entry.start + defaultLength)
            let lane = laneEnds.firstIndex { $0 <= entry.start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(visualEnd) } else { laneEnds[lane] = visualEnd }
            group.append(Placed(item: entry.item, start: entry.start, end: entry.end, lane: lane, lanes: 1))
            groupEnd = max(groupEnd, visualEnd)
        }
        close()
        return placed
    }

    /// All-day items first, then by time and title.
    static func sorted(_ items: [CalendarItem]) -> [CalendarItem] {
        items.sorted { a, b in
            if a.allDay != b.allDay { return a.allDay }
            let ta = minutes(a.time) ?? -1, tb = minutes(b.time) ?? -1
            if ta != tb { return ta < tb }
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }
}
