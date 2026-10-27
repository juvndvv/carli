import SwiftUI

/// Labels shared by every habit screen, as in the Flutter `habits_format`.
enum HabitFormat {
    /// 8 → "8", 1.5 → "1,5", 0.25 → "0,25".
    static func number(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.005 { return String(Int(value.rounded())) }
        var text = String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(",") { text.removeLast() }
        return text
    }

    static func amount(_ value: Double, _ unit: String?) -> String {
        let unit = unit?.trimmingCharacters(in: .whitespaces) ?? ""
        return unit.isEmpty ? number(value) : "\(number(value)) \(unit)"
    }

    static func valueLabel(_ today: HabitToday) -> String {
        let habit = today.habit
        switch habit.kind {
        case .check where today.weekly: return "\(number(today.value)) de \(number(today.target))"
        case .check: return today.met ? "Hecho" : "Sin hacer"
        case .quantity: return "\(number(today.value)) / \(amount(today.target, habit.unit))"
        case .avoid where today.target <= 0:
            return today.value > 0 ? "Recaída" : cleanLabel(today.streakCount, weekly: today.weekly)
        case .avoid: return "\(number(today.value)) de \(amount(today.target, habit.unit))\(today.isOver ? " · pasado" : "")"
        }
    }

    static func cleanLabel(_ streak: Int, weekly: Bool) -> String {
        switch (streak, weekly) {
        case (1, false): "1 día sin"
        case (_, false): "\(streak) días sin"
        case (1, true): "1 semana sin"
        default: "\(streak) semanas sin"
        }
    }

    static func streakLabel(_ streak: Int, weekly: Bool) -> String {
        weekly ? "Racha \(streak) sem" : "Racha \(streak)"
    }

    static func streakLength(_ streak: Int, weekly: Bool) -> String {
        switch (streak, weekly) {
        case (1, false): "1 día"
        case (_, false): "\(streak) días"
        case (1, true): "1 semana"
        default: "\(streak) semanas"
        }
    }

    static func goalLine(_ today: HabitToday) -> String {
        if today.weekly && today.met { return "Hecho esta semana" }
        if today.weekly && today.daysLeft > 0 {
            return "\(today.habit.goalText) · \(today.daysLeft == 1 ? "queda 1 día" : "quedan \(today.daysLeft) días")"
        }
        return today.habit.goalText
    }

    static func percent(_ value: Int?) -> String { value.map { "\($0) %" } ?? "—" }

    static func trend(_ trend: Int?) -> String {
        guard let trend else { return "" }
        return trend == 0 ? "=" : trend > 0 ? "↑ \(trend)" : "↓ \(-trend)"
    }

    static func since(_ start: Date) -> String {
        let c = CarliDate.calendar.dateComponents([.day, .month], from: start)
        return "desde el \(c.day!) de \(CarliDate.months[c.month! - 1])"
    }

    /// ISO week number (weeks start on Monday, week 1 holds the first Thursday).
    static func isoWeek(_ date: Date) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.component(.weekOfYear, from: date)
    }

    /// "27 de octubre" or "hoy".
    static func dayPhrase(_ date: Date) -> String {
        let c = CarliDate.calendar.dateComponents([.day, .month], from: date)
        return "\(c.day!) de \(CarliDate.months[c.month! - 1])"
    }
}

/// What the log sheet edits: one habit on one day.
struct HabitLogTarget: Identifiable {
    var habit: Habit
    var date: Date
    var value: Double
    var target: Double
    var note: String?
    var canChangeDay = true

    var id: String { "\(habit.id):\(CarliDate.isoDay(date))" }

    init(habit: Habit, date: Date, value: Double, target: Double, note: String?, canChangeDay: Bool = true) {
        self.habit = habit
        self.date = date
        self.value = value
        self.target = target
        self.note = note
        self.canChangeDay = canChangeDay
    }

    init(today: HabitToday) {
        self.init(habit: today.habit, date: .now, value: today.todayValue, target: today.logTarget, note: today.todayNote)
    }
}

/// Every habit write goes through here so every screen refreshes together, with "Deshacer" after a log.
@Observable
final class HabitActions {
    let api: APIClient
    var toast: String?
    var undo: UndoOffer?
    var logging: HabitLogTarget?

    init(api: APIClient) {
        self.api = api
    }

    static func changed() {
        NotificationCenter.default.post(name: .habitsChanged, object: nil)
    }

    private struct Entry: Encodable {
        var value: Double
        var note: String?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(value, forKey: .value)
            if let note { try c.encode(note, forKey: .note) }
        }

        private enum CodingKeys: String, CodingKey { case value, note }
    }

    private func put(_ habit: Habit, _ date: Date, _ value: Double, note: String?) async throws {
        let _: Empty = try await api.put("v1/habits/\(habit.id)/entries/\(CarliDate.isoDay(date))",
                                         body: Entry(value: value, note: note))
    }

    /// One tap on a ring: marks a yes/no habit (or unmarks it) and adds one to a quantity or an avoid habit.
    func tap(_ today: HabitToday) {
        Task { await log(today.habit, previous: today.todayValue, value: today.nextTapValue, note: today.todayNote) }
    }

    @discardableResult
    func log(_ habit: Habit, previous: Double, value: Double, date: Date = .now, note: String? = nil) async -> Bool {
        do {
            try await put(habit, date, value, note: note)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido registrar \(habit.name).")
            return false
        }
        Self.changed()
        undo = UndoOffer(text: message(habit, previous: previous, value: value, date: date)) { [weak self] in
            do {
                try await self?.put(habit, date, previous, note: note)
                Self.changed()
            } catch {
                self?.toast = error.apiMessage(fallback: "No se ha podido deshacer.")
            }
        }
        return true
    }

    private func message(_ habit: Habit, previous: Double, value: Double, date: Date) -> String {
        let when = CarliDate.calendar.isDateInToday(date) ? "" : " el \(HabitFormat.dayPhrase(date))"
        switch habit.kind {
        case .check: return value > 0 ? "\(habit.name): hecho\(when)" : "\(habit.name): desmarcado\(when)"
        case .avoid where value > previous: return "\(habit.name): registrado\(when)"
        default: return "\(habit.name): \(HabitFormat.amount(value, habit.unit))\(when)"
        }
    }

    /// Runs a write, reports failures as a toast and refreshes everything on success.
    @discardableResult
    func run<T>(_ fallback: String, _ action: () async throws -> T) async -> T? {
        do {
            let result = try await action()
            Self.changed()
            return result
        } catch {
            toast = error.apiMessage(fallback: fallback)
            return nil
        }
    }

    func setShowInTasks(_ habit: Habit, _ value: Bool) async {
        await run("No se ha podido guardar el hábito.") {
            let _: Empty = try await api.patch("v1/habits/\(habit.id)", body: Patch(["show_in_tasks": .bool(value)]))
        }
    }

    func transition(_ habit: Habit, _ action: String) async {
        await run("No se ha podido actualizar el hábito.") {
            let _: Empty = try await api.post("v1/habits/\(habit.id)/\(action)")
        }
    }

    func delete(_ habit: Habit) async -> Bool {
        await run("No se ha podido borrar el hábito.") { try await api.delete("v1/habits/\(habit.id)") } != nil
    }

    func reorder(_ ids: [String]) async {
        struct Order: Encodable { var ids: [String] }
        await run("No se ha podido reordenar.") {
            let _: Empty = try await api.put("v1/habits/order", body: Order(ids: ids))
        }
    }

    func startBreak(from: Date, to: Date, habitId: String?) async -> Bool {
        var fields: [String: JSONValue] = ["from_date": .string(CarliDate.isoDay(from)), "to_date": .string(CarliDate.isoDay(to))]
        if let habitId { fields["habit_id"] = .string(habitId) }
        return await run("No se ha podido guardar el descanso.") { () async throws -> Void in
            let _: Empty = try await api.post("v1/habits/breaks", body: Patch(fields))
        } != nil
    }

    func endBreak(_ pause: HabitBreak) async {
        await run("No se ha podido terminar el descanso.") {
            let _: Empty = try await api.post("v1/habits/breaks/\(pause.id)/end")
        }
    }
}

private struct HabitActionModifiers: ViewModifier {
    @Bindable var actions: HabitActions

    func body(content: Content) -> some View {
        content
            .sheet(item: $actions.logging) { target in
                HabitLogSheet(actions: actions, target: target)
            }
            .undoBar($actions.undo, seconds: 4)
            .carliToast($actions.toast)
    }
}

extension View {
    /// Log sheet, "Deshacer" bar and error toasts for a screen that logs habits.
    func habitActions(_ actions: HabitActions) -> some View { modifier(HabitActionModifiers(actions: actions)) }

    /// Reloads when any habit write happens anywhere.
    func onHabitsChanged(_ reload: @escaping () async -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .habitsChanged)) { _ in Task { await reload() } }
    }
}

// MARK: Other modules

/// Habits shown as rings in Tareas · Hoy: due today, not met yet, never the avoid ones.
enum HabitsForTasks {
    static func load(_ api: APIClient) async -> [HabitToday] {
        guard let modules: DataEnvelope<[AppModule]> = try? await api.get("v1/modules"),
              modules.data.contains(where: { $0.id == AppModule.habits && $0.isOn }) else { return [] }
        let settings = await ModuleSettings.load(api, module: AppModule.habits, as: HabitsSettings.self)
        guard settings?.showInTasks ?? true else { return [] }
        guard let today: DataEnvelope<HabitsToday> = try? await api.get("v1/habits/today") else { return [] }
        return today.data.pending.filter(\.habit.showInTasks)
    }
}

enum HabitConversion {
    /// Daily or weekly templates (every week, no interval) are the only ones that read as habits.
    static func canConvert(rrule: String?) -> Bool {
        guard let rrule else { return false }
        var parts: [String: String] = [:]
        for part in rrule.split(separator: ";") where part.contains("=") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            parts[pair[0]] = pair.count > 1 ? pair[1] : ""
        }
        let interval = Int(parts["INTERVAL"] ?? "1") ?? 1
        let days = parts["BYDAY"]?.split(separator: ",") ?? []
        return interval == 1 && (parts["FREQ"] == "DAILY" || parts["FREQ"] == "WEEKLY")
            && parts["BYMONTHDAY"] == nil && parts["BYSETPOS"] == nil && days.allSatisfy { $0.count == 2 }
    }

    static func habitsEnabled(_ api: APIClient) async -> Bool {
        guard let modules: DataEnvelope<[AppModule]> = try? await api.get("v1/modules") else { return false }
        return modules.data.contains { $0.id == AppModule.habits && $0.isOn }
    }
}
