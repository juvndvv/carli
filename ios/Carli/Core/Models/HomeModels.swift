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

struct TaskItem: Decodable, Identifiable, Equatable {
    var id: String
    var title: String
    var status: String?
    var dueDate: String?
    var dueTime: String?
    var overdue: Bool?
    var important: Bool?

    var isDone: Bool { status == "done" }
}

struct TasksToday: Decodable, Equatable {
    struct Progress: Decodable, Equatable {
        var done: Int
        var total: Int
    }

    var date: String
    var overdue: [TaskItem]
    var today: [TaskItem]
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

struct HabitToday: Decodable, Identifiable, Equatable {
    var id: String
    var name: String
    var icon: String
    var kind: String
    var unit: String?
    var period: String?
    var target: Double
    var value: Double
    var todayValue: Double
    var met: Bool
    var over: Bool?
    var progress: Double
    var streak: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, kind, unit, period, target, value, todayValue, met, over, progress, streak
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "check"
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "check"
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        period = try c.decodeIfPresent(String.self, forKey: .period)
        target = try c.decodeIfPresent(Double.self, forKey: .target) ?? 0
        value = try c.decodeIfPresent(Double.self, forKey: .value) ?? 0
        todayValue = try c.decodeIfPresent(Double.self, forKey: .todayValue) ?? 0
        met = try c.decodeIfPresent(Bool.self, forKey: .met) ?? false
        over = try c.decodeIfPresent(Bool.self, forKey: .over)
        progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        streak = try c.decodeIfPresent(Int.self, forKey: .streak)
    }

    var isAvoid: Bool { kind == "avoid" }
    var weekly: Bool { period == "week" }

    var valueLabel: String {
        let amount = { (v: Double) in [Plural.number(v), self.unit].compactMap { $0 }.joined(separator: " ") }
        switch kind {
        case "check" where weekly: return "\(Plural.number(value)) de \(Plural.number(target))"
        case "check": return met ? "Hecho" : "Sin hacer"
        case "quantity": return "\(Plural.number(value)) / \(amount(target))"
        default: return "\(Plural.number(value)) de \(amount(target))"
        }
    }

    /// What a tap logs today: checks toggle, quantities add one.
    var nextTapValue: Double {
        kind == "check" ? (todayValue > 0 ? 0 : 1) : todayValue + 1
    }
}

struct HabitsToday: Decodable, Equatable {
    struct Summary: Decodable, Equatable {
        var done: Int
        var total: Int
    }

    var date: String
    var summary: Summary
    var habits: [HabitToday]

    var pending: [HabitToday] { habits.filter { !$0.isAvoid && !$0.met } }
}

// MARK: Notes

struct NoteItem: Decodable, Identifiable, Equatable {
    var id: String
    var noteId: String
    var productId: String?
    var text: String
    var quantity: String?
    var sectionId: String?
    var checkedAt: String?
    var position: Int

    var checked: Bool { checkedAt != nil }
}

struct Note: Decodable, Identifiable, Equatable {
    var id: String
    var type: String
    var title: String?
    var body: String?
    var pinnedAt: String?
    var archivedAt: String?
    var deletedAt: String?
    var isPrimary: Bool?
    var sort: Int?
    var items: [NoteItem]

    var active: Bool { archivedAt == nil && deletedAt == nil }
    var isShopping: Bool { type == "shopping" }
    var openCount: Int { items.filter { !$0.checked }.count }

    var displayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        let firstLine = (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").first
        if let firstLine, !firstLine.isEmpty { return String(firstLine) }
        switch type {
        case "shopping": return "Lista de la compra"
        case "list": return "Lista sin título"
        default: return "Nota sin título"
        }
    }
}

struct NotesSnapshot: Decodable, Equatable {
    var notes: [Note]

    var primaryShopping: Note? {
        let lists = notes.filter { $0.active && $0.isShopping }
        return lists.first { $0.isPrimary == true } ?? lists.first
    }

    var pinned: [Note] { notes.filter { $0.active && $0.pinnedAt != nil } }
}
