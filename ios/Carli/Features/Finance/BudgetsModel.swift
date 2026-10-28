import Foundation
import Observation

/// Data for Finanzas › Presupuestos: the budgets of a period and their totals.
@Observable
final class BudgetsModel {
    enum State { case loading, loaded(BudgetOverview), failed(String) }

    var state: State = .loading
    var periods: [FinancePeriod] = []
    var selectedPeriodId: String?
    var settings: FinanceSettings?
    var categories: [FinanceCategory] = []
    var copying = false

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var overview: BudgetOverview? {
        if case .loaded(let overview) = state { overview } else { nil }
    }

    var selectedPeriod: FinancePeriod? {
        periods.first { $0.id == selectedPeriodId } ?? overview?.meta.period
    }

    var warningThreshold: Int { settings?.budgetWarningThreshold ?? 80 }

    func load() async {
        async let periods: Void = loadPeriods()
        async let settings: Void = loadSettings()
        async let categories: Void = loadCategories()
        async let overview: Void = loadOverview()
        _ = await (periods, settings, categories, overview)
    }

    func select(_ period: FinancePeriod) async {
        selectedPeriodId = period.id
        await loadOverview()
    }

    func loadOverview() async {
        do {
            let query = selectedPeriodId.map { ["period_id": $0] } ?? [:]
            state = .loaded(try await api.get("v1/finance/budgets", query: query))
        } catch {
            if overview == nil { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
    }

    /// Copies the previous period's budgets; returns the toast to show.
    func copy(from previous: FinancePeriod) async -> String {
        guard let period = overview?.meta.period else { return "" }
        copying = true
        defer { copying = false }
        do {
            let result: BudgetOverview = try await api.post("v1/finance/budgets/copy",
                                                            body: ["from_period_id": previous.id, "to_period_id": period.id])
            state = .loaded(result)
            let name = previous.shortName ?? previous.name
            switch result.meta.copied ?? 0 {
            case 0: return "No había nada nuevo que copiar de \(name)"
            case 1: return "1 presupuesto copiado de \(name)"
            case let count: return "\(count) presupuestos copiados de \(name)"
            }
        } catch {
            return error.apiMessage(fallback: "No se han podido copiar los presupuestos.")
        }
    }

    func save(_ changes: [BudgetChange]) async throws {
        guard let period = overview?.meta.period else { return }
        let result: BudgetOverview = try await api.put("v1/finance/budgets", body: BudgetUpsert(periodId: period.id, budgets: changes))
        state = .loaded(result)
    }

    private func loadPeriods() async {
        if let envelope: DataEnvelope<[FinancePeriod]> = try? await api.get("v1/finance/periods") {
            periods = envelope.data
        }
    }

    private func loadSettings() async {
        if let envelope: DataEnvelope<FinanceSettings> = try? await api.get("v1/finance/settings") {
            settings = envelope.data
        }
    }

    private func loadCategories() async {
        if let envelope: DataEnvelope<[FinanceCategory]> = try? await api.get("v1/finance/categories") {
            categories = envelope.data
        }
    }
}

struct BudgetUpsert: Encodable {
    var periodId: String
    var budgets: [BudgetChange]
}

/// One edited line. A nil amount removes the budget, so it's sent as an explicit null.
struct BudgetChange: Encodable, Equatable {
    var categoryId: String
    var amountCents: Int?
    var rollover: Bool

    private enum CodingKeys: String, CodingKey { case categoryId, amountCents, rollover }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(amountCents, forKey: .amountCents)
        try container.encode(rollover, forKey: .rollover)
    }
}

/// A row of the budget editor: every expense category, budgeted or not.
struct BudgetEditorLine: Identifiable, Equatable {
    var categoryId: String
    var name: String
    var icon: String
    var isChild: Bool
    var initialAmount: Int?
    var initialRollover: Bool
    var amountText: String
    var rollover: Bool

    var id: String { categoryId }
    var amount: Int? { Money.parse(amountText) }
    var isValid: Bool { amountText.trimmingCharacters(in: .whitespaces).isEmpty || amount != nil }
    var changed: Bool { amount != initialAmount || rollover != initialRollover }

    /// Parents then their children, followed by budgets whose category is no longer listed.
    static func build(categories: [FinanceCategory], rows: [BudgetRow]) -> [BudgetEditorLine] {
        var existing = Dictionary(rows.compactMap { row in row.categoryId.map { ($0, row) } }, uniquingKeysWith: { first, _ in first })
        var lines: [BudgetEditorLine] = []
        func add(_ id: String, _ name: String, _ icon: String, child: Bool) {
            let row = existing.removeValue(forKey: id)
            lines.append(BudgetEditorLine(categoryId: id, name: name, icon: icon, isChild: child,
                                          initialAmount: row?.amountCents, initialRollover: row?.rollover ?? false,
                                          amountText: row.map { Money.input($0.amountCents) } ?? "",
                                          rollover: row?.rollover ?? false))
        }
        for parent in categories where parent.kind == "expense" && parent.archived != true {
            add(parent.id, parent.name, parent.icon ?? "tag", child: false)
            for child in parent.children ?? [] where child.archived != true {
                add(child.id, child.name, child.icon ?? parent.icon ?? "tag", child: true)
            }
        }
        for row in rows {
            guard let id = row.categoryId, existing[id] != nil else { continue }
            add(id, row.category.name, row.category.icon ?? "tag", child: row.category.parent != nil)
        }
        return lines
    }

    static func changes(_ lines: [BudgetEditorLine]) -> [BudgetChange] {
        lines.filter { $0.changed && !($0.amount == nil && $0.initialAmount == nil) }
            .map { BudgetChange(categoryId: $0.categoryId, amountCents: $0.amount, rollover: $0.rollover) }
    }
}
