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
    /// Narrowing that only links set (a notification, search or another screen); "Limpiar" drops it.
    var tags: Set<String> = []
    var from: String?
    var to: String?
    var minCents: Int?
    var maxCents: Int?
    var clearedOnly = false
    var debtId: String?
    var recurringRuleId: String?
    var contactId: String?

    var linkedCount: Int {
        [!tags.isEmpty, from != nil || to != nil, minCents != nil || maxCents != nil, clearedOnly,
         debtId != nil, recurringRuleId != nil, contactId != nil].filter { $0 }.count
    }

    var activeCount: Int {
        [!accountIds.isEmpty, !categoryIds.isEmpty, !kinds.isEmpty, pendingOnly, uncategorized].filter { $0 }.count + linkedCount
    }

    var isFiltering: Bool { activeCount > 0 || !trimmedQuery.isEmpty }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Reads the Flutter link query (`?categoria=…&periodo=todos&sin_categoria=1`), as notifications and search send it.
    static func fromLink(_ query: [String: String]) -> TransactionFilters {
        func list(_ key: String) -> [String] {
            (query[key] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        func day(_ key: String) -> String? {
            guard let text = query[key], text.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil else { return nil }
            return text
        }
        func cents(_ key: String) -> Int? { query[key].flatMap { $0.wholeMatch(of: /\d+/) != nil ? Int($0) : nil } }
        let kindNames: [String: TransactionKind] = ["gasto": .expense, "gastos": .expense, "expense": .expense,
                                                     "ingreso": .income, "ingresos": .income, "income": .income,
                                                     "transferencia": .transfer, "transferencias": .transfer, "transfer": .transfer,
                                                     "ajuste": .adjustment, "ajustes": .adjustment, "adjustment": .adjustment]
        var filters = TransactionFilters()
        filters.query = query["q"] ?? ""
        filters.from = day("desde")
        filters.to = day("hasta")
        switch query["periodo"] {
        case "todos": filters.allPeriods = true
        case "actual", nil: filters.allPeriods = !filters.query.isEmpty || filters.from != nil || filters.to != nil
        case let id?: filters.periodId = id
        }
        filters.accountIds = Set(list("cuenta"))
        filters.categoryIds = Set(list("categoria"))
        filters.tags = Set(list("etiqueta").map { $0.replacing(/^#/, with: "").lowercased() })
        filters.kinds = Set(list("tipo").compactMap { kindNames[$0] })
        filters.minCents = cents("min")
        filters.maxCents = cents("max")
        switch query["estado"] {
        case "pendiente", "pending": filters.pendingOnly = true
        case "confirmado", "cleared": filters.clearedOnly = true
        default: break
        }
        filters.uncategorized = ["1", "true", "si", "sí"].contains(query["sin_categoria"]?.lowercased() ?? "")
        filters.debtId = query["deuda"]
        filters.recurringRuleId = query["recurrente"]
        filters.contactId = query["contacto"]
        return filters
    }

    /// Clears everything but the period.
    func cleared() -> TransactionFilters {
        TransactionFilters(periodId: periodId, allPeriods: allPeriods)
    }

    /// The API takes comma-separated lists.
    func apiQuery(currentPeriodId: String?) -> [String: String] {
        var query: [String: String] = [:]
        if from == nil, to == nil, !allPeriods, let period = periodId ?? currentPeriodId { query["period_id"] = period }
        if let from { query["from"] = from }
        if let to { query["to"] = to }
        if !tags.isEmpty { query["tag"] = tags.sorted().joined(separator: ",") }
        if let minCents { query["min"] = "\(minCents)" }
        if let maxCents { query["max"] = "\(maxCents)" }
        if clearedOnly { query["status"] = "cleared" }
        if let debtId { query["debt_id"] = debtId }
        if let recurringRuleId { query["recurring_rule_id"] = recurringRuleId }
        if let contactId { query["contact_id"] = contactId }
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
