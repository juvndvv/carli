import Foundation
import Observation

/// Data for Finanzas › Movimientos: a filtered, cursor-paged list of movements.
@Observable
final class TransactionsModel {
    enum State: Equatable { case loading, loaded, failed(String) }

    static let pageSize = 50

    var state: State = .loading
    var filters = TransactionFilters()
    var items: [FinanceTransaction] = []
    var totals: TransactionTotals?
    var pendingCount: Int?
    var hasMore = false
    var loadingMore = false

    var periods: [FinancePeriod] = []
    var accounts: [AccountRef] = []
    var categories: [FinanceCategory] = []
    var tags: [FinanceTag] = []

    private var cursor: String?
    private var generation = 0
    let api: APIClient

    init(api: APIClient, filters: TransactionFilters = TransactionFilters()) {
        self.api = api
        self.filters = filters
    }

    var currentPeriod: FinancePeriod? { periods.first { $0.isCurrent == true } }

    var groups: [DayGroup] {
        DayGroup.build(items, hideIncomingTransfers: filters.accountIds.isEmpty)
    }

    /// Categories in picker order: each parent followed by its children.
    var categoryOptions: [(category: FinanceCategory, isChild: Bool)] {
        categories.filter { $0.archived != true }.flatMap { parent in
            [(parent, false)] + (parent.children ?? []).filter { $0.archived != true }.map { ($0, true) }
        }
    }

    /// Periods first: the list's default filter is the current period.
    func load() async {
        await loadPeriods()
        async let accounts: Void = loadAccounts()
        async let categories: Void = loadCategories()
        async let list: Void = reload()
        _ = await (accounts, categories, list)
        if let envelope: DataEnvelope<[FinanceTag]> = try? await api.get("v1/finance/tags") { tags = envelope.data }
    }

    /// Applies `changes` (category, account, tags or status) to the selected movements; returns how many changed.
    func bulkUpdate(_ ids: [String], _ changes: [String: JSONValue]) async throws -> Int {
        struct Result: Decodable { var updated: Int }
        var body = changes
        body["ids"] = .array(ids.map(JSONValue.string))
        let result: DataEnvelope<Result> = try await api.patch("v1/finance/transactions/bulk", body: Patch(body))
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        return result.data.updated
    }

    /// The CSV of what the list shows, written to a temporary file for the share sheet.
    func exportCSV() async throws -> URL {
        let data = try await api.download("v1/finance/transactions/export.csv",
                                          query: filters.apiQuery(currentPeriodId: currentPeriod?.id), accept: "text/csv")
        let url = FileManager.default.temporaryDirectory.appending(path: "movimientos-\(CarliDate.isoDay(.now)).csv")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Fetches the first page for the current filters. Older responses are dropped if the
    /// filters change while they're in flight.
    func reload() async {
        generation += 1
        let mine = generation
        let query = filters.apiQuery(currentPeriodId: currentPeriod?.id)
        do {
            async let pending = pendingCount(query)
            let first: TransactionPage = try await api.get("v1/finance/transactions",
                                                           query: query.merging(["per_page": "\(Self.pageSize)"]) { $1 })
            let pendingTotal = await pending
            guard mine == generation else { return }
            items = first.data
            totals = first.meta.totals
            cursor = first.meta.nextCursor
            hasMore = first.meta.hasMore ?? false
            pendingCount = pendingTotal
            state = .loaded
        } catch {
            guard mine == generation else { return }
            if state != .loaded { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
    }

    func loadMore() async {
        guard hasMore, !loadingMore, let cursor else { return }
        loadingMore = true
        defer { loadingMore = false }
        let mine = generation
        var query = filters.apiQuery(currentPeriodId: currentPeriod?.id)
        query["per_page"] = "\(Self.pageSize)"
        query["cursor"] = cursor
        guard let page: TransactionPage = try? await api.get("v1/finance/transactions", query: query), mine == generation else { return }
        let known = Set(items.map(\.id))
        items += page.data.filter { !known.contains($0.id) }
        self.cursor = page.meta.nextCursor
        hasMore = page.meta.hasMore ?? false
    }

    /// Removes the row straight away; puts it back if the server refuses.
    func delete(_ transaction: FinanceTransaction) async throws {
        let index = items.firstIndex { $0.id == transaction.id }
        items.removeAll { $0.id == transaction.id }
        do {
            try await api.delete("v1/finance/transactions/\(transaction.id)")
        } catch {
            if let index { items.insert(transaction, at: min(index, items.count)) }
            throw error
        }
        await reload()
    }

    func restore(_ transaction: FinanceTransaction) async throws {
        let _: Empty = try await api.post("v1/finance/transactions/\(transaction.id)/restore")
        await reload()
    }

    /// How many pending movements match, for the "Pendientes" chip.
    private func pendingCount(_ query: [String: String]) async -> Int? {
        let page: TransactionPage? = try? await api.get("v1/finance/transactions",
                                                        query: query.merging(["status": "pending", "per_page": "1"]) { $1 })
        return page?.meta.totals.count
    }

    private func loadPeriods() async {
        if let envelope: DataEnvelope<[FinancePeriod]> = try? await api.get("v1/finance/periods") {
            periods = envelope.data
        }
    }

    private func loadAccounts() async {
        if let envelope: DataEnvelope<[AccountRef]> = try? await api.get("v1/finance/accounts", query: ["include_archived": "1"]) {
            accounts = envelope.data
        }
    }

    private func loadCategories() async {
        if let envelope: DataEnvelope<[FinanceCategory]> = try? await api.get("v1/finance/categories") {
            categories = envelope.data
        }
    }
}
