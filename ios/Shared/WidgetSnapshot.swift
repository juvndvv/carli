import Foundation

/// What `GET v1/finance/widget` returns: the period at a glance, today and the latest expenses.
struct WidgetSnapshot: Codable, Equatable {
    struct Period: Codable, Equatable {
        var startDate: String
        var endDate: String
        var remainingDays: Int
        var spentCents: Int
        var budgetedCents: Int
        var budgetRemainingCents: Int
        var budgetPercentBp: Int?
    }

    struct Today: Codable, Equatable {
        var spentCents: Int
        var count: Int
    }

    struct Expense: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var amountCents: Int
        var date: String
    }

    var period: Period
    var today: Today
    var latest: [Expense]

    var hasBudget: Bool { period.budgetedCents > 0 }

    /// Share of the budget already spent, 0...1; nil without budgets.
    var budgetFraction: Double? {
        guard hasBudget, let bp = period.budgetPercentBp else { return nil }
        return min(max(Double(bp) / 10_000, 0), 1)
    }

    static let sample = WidgetSnapshot(
        period: Period(startDate: "2026-10-01", endDate: "2026-11-06", remainingDays: 9, spentCents: 81_200,
                       budgetedCents: 140_000, budgetRemainingCents: 58_800, budgetPercentBp: 5_800),
        today: Today(spentCents: 5_455, count: 2),
        latest: [
            Expense(id: "1", name: "Mercadona", amountCents: -4_215, date: "2026-10-28"),
            Expense(id: "2", name: "Cabify", amountCents: -1_240, date: "2026-10-28"),
        ]
    )
}
