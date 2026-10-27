import Foundation

/// A category from /finance/categories: top level with its children nested.
struct FinanceCategory: Decodable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var kind: String
    var icon: String?
    var archived: Bool?
    var children: [FinanceCategory]?
    var parentId: String? = nil
    var color: String? = nil
    var opensPeriod: Bool? = nil

    var isArchived: Bool { archived == true }
}

struct FinanceTag: Decodable, Equatable, Identifiable {
    var id: String
    var name: String
    var transactionsCount: Int?
}

struct TransactionTotals: Decodable, Equatable {
    var count: Int
    var incomeCents: Int
    var expenseCents: Int
}

struct TransactionPage: Decodable {
    struct Meta: Decodable {
        var nextCursor: String?
        var hasMore: Bool?
        var totals: TransactionTotals
    }

    var data: [FinanceTransaction]
    var meta: Meta
}

enum TransactionKind: String, CaseIterable, Identifiable {
    case expense, income, transfer, adjustment

    var id: String { rawValue }

    var plural: String {
        switch self {
        case .expense: "Gastos"
        case .income: "Ingresos"
        case .transfer: "Transferencias"
        case .adjustment: "Ajustes"
        }
    }
}

/// Where a link inside Finanzas leads.
enum FinanceRoute {
    case budgets
    case transactions(TransactionFilters)
}

/// What Movimientos is showing. `periodId` nil with `allPeriods` false means the current period.
struct TransactionFilters: Hashable {
    static let noCategory = "none"

    var periodId: String?
    var allPeriods = false
    var accountIds: Set<String> = []
    var categoryIds: Set<String> = []
    var kinds: Set<TransactionKind> = []
    var query = ""
    var pendingOnly = false
    var uncategorized = false

    var activeCount: Int {
        [!accountIds.isEmpty, !categoryIds.isEmpty, !kinds.isEmpty, pendingOnly, uncategorized].filter { $0 }.count
    }

    var isFiltering: Bool { activeCount > 0 || !trimmedQuery.isEmpty }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Clears everything but the period.
    func cleared() -> TransactionFilters {
        TransactionFilters(periodId: periodId, allPeriods: allPeriods)
    }

    /// The API takes comma-separated lists.
    func apiQuery(currentPeriodId: String?) -> [String: String] {
        var query: [String: String] = [:]
        if !allPeriods, let period = periodId ?? currentPeriodId { query["period_id"] = period }
        if !accountIds.isEmpty { query["account_id"] = accountIds.sorted().joined(separator: ",") }
        if !categoryIds.isEmpty { query["category_id"] = categoryIds.sorted().joined(separator: ",") }
        if !kinds.isEmpty { query["kind"] = kinds.map(\.rawValue).sorted().joined(separator: ",") }
        if !trimmedQuery.isEmpty { query["q"] = trimmedQuery }
        if pendingOnly { query["status"] = "pending" }
        if uncategorized { query["uncategorized"] = "1" }
        return query
    }
}

/// One day of movements with its net total (transfers don't count).
struct DayGroup: Identifiable, Equatable {
    var date: String
    var items: [FinanceTransaction] = []
    var totalCents = 0

    var id: String { date }

    /// Groups consecutive same-day movements. Without an account filter both legs of a
    /// transfer would show, so the incoming one is hidden while its outgoing leg is listed.
    static func build(_ transactions: [FinanceTransaction], hideIncomingTransfers: Bool) -> [DayGroup] {
        var groups: [DayGroup] = []
        for transaction in transactions {
            if hideIncomingTransfers, transaction.isTransfer, transaction.amountCents > 0, let group = transaction.transferGroupId,
               transactions.contains(where: { $0.transferGroupId == group && $0.id != transaction.id }) {
                continue
            }
            if groups.last?.date != transaction.date { groups.append(DayGroup(date: transaction.date)) }
            groups[groups.count - 1].items.append(transaction)
            if !transaction.isTransfer { groups[groups.count - 1].totalCents += transaction.amountCents }
        }
        return groups
    }
}

extension Plural {
    static func movements(_ count: Int) -> String {
        count == 1 ? "1 movimiento" : "\(count) movimientos"
    }
}

extension CarliDate {
    /// "Hoy", "Ayer" or "Lunes, 27 de octubre" for list headers.
    static func dayTitle(_ iso: String, now: Date = .now) -> String {
        guard let date = day(iso) else { return iso }
        if calendar.isDate(date, inSameDayAs: now) { return "Hoy" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ayer"
        }
        return long(date)
    }
}
