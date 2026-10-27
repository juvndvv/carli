import Foundation

/// `{ "data": ... }` envelope used by most endpoints.
struct DataEnvelope<T: Decodable>: Decodable {
    var data: T
}

struct AppModule: Decodable, Identifiable, Equatable {
    var id: String
    var name: String
    var icon: String
    var route: String?
    var description: String?
    var available: Bool?
    var enabled: Bool?

    var comingSoon: Bool { available == false }
    var isOn: Bool { enabled == true && !comingSoon }

    static let finance = "finance", tasks = "tasks", notes = "notes", habits = "habits"
}

// MARK: Finance

struct FinancePeriod: Decodable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var startDate: String?
    var shortName: String?
    var rangeLabel: String?
    var daysRemaining: Int?
    var isCurrent: Bool?
    var expectedEndDate: String?
    var openedBy: String?
    var label: String?

    var openedByLabel: String {
        switch openedBy {
        case "manual": "Manual"
        case "calendar": "Mes natural"
        default: "Por nómina"
        }
    }

    /// "1 oct – 31 oct · quedan 4 días" for the current period, the range otherwise.
    var subtitle: String {
        let range = rangeLabel ?? ""
        guard isCurrent == true, let days = daysRemaining else { return range }
        return "\(range) · \(Plural.daysLeft(days))"
    }
}

struct BudgetTotals: Decodable, Equatable {
    var budgetedCents: Int
    var spentCents: Int
    var remainingCents: Int
    var percentBp: Int?
    var projectedCents: Int?
}

struct FinanceSummary: Decodable, Equatable {
    var period: FinancePeriod
    var spentCents: Int
    var netWorthCents: Int
    var budget: BudgetTotals
}

struct FinanceSettings: Decodable, Equatable {
    var budgetWarningThreshold: Int?
    var savingsTargetPercent: Int?
    var periodMode: String?
}

// MARK: Pending

struct PendingSummary: Decodable, Equatable {
    struct Entry: Decodable, Equatable, Identifiable {
        var module: String
        var moduleName: String?
        var type: String
        var count: Int
        var id: String { "\(module):\(type)" }
    }

    var total: Int
    var byModule: [Entry]
}

enum PendingType {
    /// Count label and SF Symbol for each kind of pending item, as in the Flutter registry.
    static func describe(_ entry: PendingSummary.Entry) -> (label: String, symbol: String) {
        let n = entry.count
        switch (entry.module, entry.type) {
        case ("finance", "transfer_suggestion"):
            return (n == 1 ? "1 posible transferencia por revisar" : "\(n) posibles transferencias por revisar", "arrow.left.arrow.right")
        case ("finance", "uncategorized_transaction"):
            return (n == 1 ? "1 movimiento por categorizar" : "\(n) movimientos por categorizar", "circle.dashed")
        case ("finance", "recurring_to_confirm"):
            return (n == 1 ? "1 recurrente por confirmar" : "\(n) recurrentes por confirmar", "repeat")
        case ("tasks", "overdue_task"):
            return (n == 1 ? "1 tarea vencida" : "\(n) tareas vencidas", "checklist")
        default:
            return (n == 1 ? "1 pendiente" : "\(n) pendientes", "tray")
        }
    }
}

// MARK: Notifications

struct AppNotification: Decodable, Identifiable, Equatable {
    var id: String
    var module: String?
    var type: String?
    var title: String
    var body: String?
    var url: String?
    var readAt: String?
    var createdAt: String?

    var unread: Bool { readAt == nil }
}

struct NotificationsPage: Decodable {
    struct Meta: Decodable {
        var unreadCount: Int?
    }

    var data: [AppNotification]
    var meta: Meta?
}

// MARK: Tasks

struct TaskItem: Decodable, Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var status: String?
    var dueDate: String?
    var dueTime: String?
    var overdue: Bool?
    var important: Bool?
    var notes: String? = nil
    var list: TaskListRef? = nil
    var completedAt: String? = nil
    var template: TaskTemplateRef? = nil
    var occurrenceDate: String? = nil
    var subtasks: [Subtask]? = nil

    var isDone: Bool { status == "done" }
    var isOpen: Bool { status == nil || status == "open" }
    var isOverdue: Bool { overdue == true }
    var isImportant: Bool { important == true }
    var repeats: Bool { template != nil }
    var steps: [Subtask] { subtasks ?? [] }
    var stepsDone: Int { steps.filter(\.done).count }
}

struct TasksToday: Decodable, Equatable {
    struct Progress: Decodable, Equatable {
        var done: Int
        var total: Int
    }

    var date: String
    var overdue: [TaskItem]
    var today: [TaskItem]
    var done: [TaskItem]? = nil
    var progress: Progress?

    var headline: String {
        let open = today.count
        let done = progress?.done ?? 0
        var parts = [open == 0 ? (done > 0 ? "Todo hecho por hoy" : "Nada para hoy")
                     : open == 1 ? "1 tarea para hoy" : "\(open) tareas para hoy"]
        if !overdue.isEmpty { parts.append(overdue.count == 1 ? "1 vencida" : "\(overdue.count) vencidas") }
        return parts.joined(separator: " · ")
    }
}

// MARK: Habits

struct HabitToday: Decodable, Identifiable, Equatable, Hashable {
    var habit: Habit
    var period: String?
    var periodEnd: String?
    var target: Double
    var value: Double
    var todayValue: Double
    var todayNote: String?
    var met: Bool
    var over: Bool?
    var progress: Double
    var daysLeft: Int
    var streak: Int?
    var consistency: Int?

    private enum CodingKeys: String, CodingKey {
        case period, periodEnd, target, value, todayValue, todayNote, met, over, progress, daysLeft, streak, consistency
    }

    init(from decoder: Decoder) throws {
        habit = try Habit(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        period = try c.decodeIfPresent(String.self, forKey: .period)
        periodEnd = try c.decodeIfPresent(String.self, forKey: .periodEnd)
        target = try c.decodeIfPresent(Double.self, forKey: .target) ?? 0
        value = try c.decodeIfPresent(Double.self, forKey: .value) ?? 0
        todayValue = try c.decodeIfPresent(Double.self, forKey: .todayValue) ?? 0
        todayNote = try c.decodeIfPresent(String.self, forKey: .todayNote)
        met = try c.decodeIfPresent(Bool.self, forKey: .met) ?? false
        over = try c.decodeIfPresent(Bool.self, forKey: .over)
        progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        daysLeft = try c.decodeIfPresent(Int.self, forKey: .daysLeft) ?? 0
        streak = try c.decodeIfPresent(Int.self, forKey: .streak)
        consistency = try c.decodeIfPresent(Int.self, forKey: .consistency)
    }

    var id: String { habit.id }
    var name: String { habit.name }
    var icon: String { habit.icon }
    var kind: String { habit.kindRaw }
    var unit: String? { habit.unit }
    var isAvoid: Bool { habit.isAvoid }
    var weekly: Bool { period == "week" }
    var isOver: Bool { over == true }
    var streakCount: Int { streak ?? 0 }

    var valueLabel: String { HabitFormat.valueLabel(self) }

    /// What a tap logs today: checks toggle, quantities and avoid habits add one.
    var nextTapValue: Double {
        habit.kind == .check ? (todayValue > 0 ? 0 : 1) : todayValue + 1
    }

    /// Target for the log sheet: weekly amounts count against the week, the rest against the goal.
    var logTarget: Double {
        weekly && habit.kind != .check ? target : habit.goal.target
    }
}

struct HabitsToday: Decodable, Equatable {
    struct Summary: Decodable, Equatable {
        var done: Int
        var total: Int
        var consistency: Int?
    }

    var date: String
    var onBreak: Bool?
    var summary: Summary
    var habits: [HabitToday]

    var pending: [HabitToday] { habits.filter { !$0.isAvoid && !$0.met } }
    var avoid: [HabitToday] { habits.filter(\.isAvoid) }
    var completed: [HabitToday] { habits.filter { !$0.isAvoid && $0.met } }
}
