import Foundation

struct CategoryRef: Decodable, Equatable {
    var id: String?
    var name: String
    var icon: String?
    var parent: String?

    var label: String { parent.map { "\($0) › \(name)" } ?? name }
}

struct AccountRef: Decodable, Equatable, Identifiable {
    var id: String
    var name: String
}

enum BudgetStatus: String, Decodable {
    case ok, warning, exceeded

    init(from decoder: Decoder) throws {
        self = BudgetStatus(rawValue: (try? decoder.singleValueContainer().decode(String.self)) ?? "") ?? .ok
    }
}

struct BudgetRow: Decodable, Equatable, Identifiable {
    var id: String
    var category: CategoryRef
    var amountCents: Int
    var rolloverInCents: Int?
    var availableCents: Int
    var spentCents: Int
    var remainingCents: Int
    var status: BudgetStatus?

    private var rollover: Int { rolloverInCents ?? 0 }
    var limitCents: Int { rollover < 0 ? amountCents : availableCents }
    var consumedCents: Int { spentCents - (rollover < 0 ? rollover : 0) }
    var barRatio: Double { limitCents > 0 ? Double(consumedCents) / Double(limitCents) : (consumedCents > 0 ? 1.01 : 0) }
    var state: BudgetStatus { status ?? .ok }

    var note: String {
        var parts = [state == .exceeded || remainingCents < 0
                     ? "Excedido en \(Money.format(abs(remainingCents)))"
                     : "Te quedan \(Money.format(remainingCents))"]
        if rollover != 0 {
            parts.append("\(rollover > 0 ? "Arrastras" : "Arrastras un exceso de") \(Money.format(rollover, .absolute))")
        }
        return parts.joined(separator: " · ")
    }
}

struct CategoryGroup: Decodable, Equatable {
    var name: String
    var color: String?
    var amountCents: Int
}

struct HistoryPoint: Decodable, Equatable, Identifiable {
    var label: String
    var incomeCents: Int
    var expenseCents: Int
    var netWorthCents: Int
    var id: String { label }
}

struct UpcomingCharge: Decodable, Equatable, Identifiable {
    var ruleId: String
    var name: String
    var date: String
    var amountCents: Int
    var category: CategoryRef?
    var id: String { "\(ruleId)-\(date)" }

    var subtitle: String {
        guard let day = CarliDate.day(date) else { return date }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: day).day ?? 0
        let when = days <= 0 ? "hoy" : days == 1 ? "mañana" : days == 2 ? "pasado mañana" : "en \(days) días"
        return "\(CarliDate.short(day)) · \(when)"
    }
}

struct FinanceTransaction: Decodable, Equatable, Identifiable {
    struct Split: Decodable, Equatable {}
    struct Share: Decodable, Equatable {}

    var id: String
    var account: AccountRef
    var kind: String
    var amountCents: Int
    var date: String
    var category: CategoryRef?
    var payee: String?
    var description: String?
    var status: String?
    var transferAccountId: String?
    var source: String?
    var uncategorized: Bool?
    var splits: [Split]?
    var shares: [Share]?

    var isTransfer: Bool { kind == "transfer" }
    var isSplit: Bool { !(splits ?? []).isEmpty }
    var fromBank: Bool { source == "bank" }
    var needsCategory: Bool { isTransfer || kind == "adjustment" || (category == nil && !isSplit) }

    var title: String {
        if let payee, !payee.isEmpty { return payee }
        if let description, !description.isEmpty { return description }
        switch kind {
        case "transfer": return amountCents < 0 ? "Transferencia enviada" : "Transferencia recibida"
        case "adjustment": return "Ajuste de saldo"
        default: return isSplit ? "Movimiento dividido" : (category?.name ?? "Sin categoría")
        }
    }

    func subtitle(accounts: [AccountRef]) -> String {
        var parts: [String] = []
        if isTransfer {
            let other = accounts.first { $0.id == transferAccountId }?.name
            let route = other.map { amountCents < 0 ? "\(account.name) → \($0)" : "\($0) → \(account.name)" } ?? account.name
            parts = ["Transferencia", route]
        } else {
            parts.append(kind == "adjustment" ? "Ajuste" : isSplit ? "\(splits?.count ?? 0) categorías" : (category?.name ?? "Sin categoría"))
            parts.append(account.name)
            if let payee, !payee.isEmpty, let description, !description.isEmpty { parts.append(description) }
        }
        return parts.joined(separator: " · ")
    }

    var symbol: String {
        switch kind {
        case "transfer": "arrow.left.arrow.right"
        case "adjustment": "scalemass"
        default: isSplit ? "arrow.triangle.branch" : CarliIcon.symbol(category?.icon ?? "circle-dashed")
        }
    }

    var amountLabel: String { Money.format(amountCents, isTransfer ? .absolute : .signed) }
}

struct UncategorizedSummary: Decodable, Equatable {
    var expenseCents: Int
    var count: Int
}

struct Dashboard: Decodable, Equatable {
    struct Deltas: Decodable, Equatable {
        var income: Int?
        var expense: Int?
    }

    struct Budgets: Decodable, Equatable {
        var top: [BudgetRow]?
        var totals: BudgetTotals?
    }

    var period: FinancePeriod
    var previousPeriod: FinancePeriod?
    var incomeCents: Int
    var expenseCents: Int
    var savingsCents: Int
    var savingsRateBp: Int?
    var netWorthCents: Int
    var netWorthDeltaCents: Int?
    var deltasBp: Deltas?
    var byCategory: [CategoryGroup]
    var history: [HistoryPoint]
    var budgets: Budgets?
    var upcoming: [UpcomingCharge]
    var recentTransactions: [FinanceTransaction]
    var uncategorized: UncategorizedSummary?
}

/// Disponible, Ahorro and Ritmo, outer to inner (same rules as the Flutter app).
struct RingFigures: Equatable {
    var budgetedCents: Int
    var remainingCents: Int
    var spentCents: Int
    var plannedByNowCents: Int
    var savingsCents: Int
    var savingsTargetCents: Int

    init(_ data: Dashboard, savingsTargetPercent: Int, now: Date = .now) {
        let totals = data.budgets?.totals
        budgetedCents = totals?.budgetedCents ?? 0
        remainingCents = totals?.remainingCents ?? 0
        spentCents = totals?.spentCents ?? 0
        plannedByNowCents = Int((Double(budgetedCents) * Self.elapsed(data.period, now: now)).rounded())
        savingsCents = data.savingsCents
        savingsTargetCents = data.incomeCents <= 0 ? 0 : Int((Double(data.incomeCents) * Double(savingsTargetPercent) / 100).rounded())
    }

    var hasBudget: Bool { budgetedCents > 0 }
    var hasSavingsTarget: Bool { savingsTargetCents > 0 }
    var available: Double? { hasBudget ? min(max(Double(remainingCents) / Double(budgetedCents), 0), 1) : nil }
    var savings: Double? { hasSavingsTarget ? min(max(Double(savingsCents) / Double(savingsTargetCents), 0), 2) : nil }
    var pace: Double? {
        guard hasBudget else { return nil }
        if plannedByNowCents <= 0 { return spentCents > 0 ? 2 : 0 }
        return min(max(Double(spentCents) / Double(plannedByNowCents), 0), 2)
    }
    var aheadOfPlan: Bool { (pace ?? 0) > 1 }

    /// Share of the period gone by, counting today. A past period is 1.
    static func elapsed(_ period: FinancePeriod, now: Date) -> Double {
        guard period.isCurrent == true, let start = period.startDate.flatMap(CarliDate.day) else { return 1 }
        let calendar = Calendar.current
        let elapsed = (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0) + 1
        if elapsed <= 0 { return 0 }
        return min(max(Double(elapsed) / Double(elapsed + (period.daysRemaining ?? 0)), 0), 1)
    }
}

/// Category slices for the donut: top seven plus "Otros", keeping each category's own chart slot when free.
struct DonutSlice: Identifiable, Equatable {
    var label: String
    var amountCents: Int
    var slot: Int?
    var id: String { label }

    static func build(_ groups: [CategoryGroup], max: Int = 8) -> [DonutSlice] {
        let sorted = groups.sorted { $0.amountCents > $1.amountCents }
        let head = sorted.count > max ? Array(sorted.prefix(max - 1)) : sorted
        let tail = sorted.count > max ? Array(sorted.dropFirst(max - 1)) : []
        var used = Set<Int>()
        let wanted: [Int?] = head.map { group in
            guard let raw = group.color, raw.count == 2, raw.first == "c", let slot = Int(raw.dropFirst()), (1...8).contains(slot),
                  used.insert(slot).inserted else { return nil }
            return slot
        }
        var free = (1...8).filter { !used.contains($0) }
        var slices = zip(head, wanted).map { group, slot in
            DonutSlice(label: group.name, amountCents: group.amountCents, slot: slot ?? (free.isEmpty ? nil : free.removeFirst()))
        }
        if !tail.isEmpty {
            slices.append(DonutSlice(label: "Otros", amountCents: tail.reduce(0) { $0 + $1.amountCents }, slot: nil))
        }
        return slices
    }
}

enum Percent {
    /// Basis points with one optional decimal: 1234 → "12,3 %", signed adds "+".
    static func format(_ bp: Int?, signed: Bool = false) -> String {
        guard let bp else { return "—" }
        let sign = bp < 0 ? Money.minus : (signed && bp > 0 ? "+" : "")
        var text = String(format: "%.1f", Double(abs(bp)) / 100)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return "\(sign)\(text.replacingOccurrences(of: ".", with: ",")) %"
    }
}
