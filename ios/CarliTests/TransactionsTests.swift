import Foundation
import Testing
@testable import Carli

struct TransactionsTests {
    private func page(_ rows: String) throws -> TransactionPage {
        let json = """
        {"data":[\(rows)],"meta":{"next_cursor":"abc","has_more":true,"totals":{"count":3,"income_cents":1000,"expense_cents":-500}}}
        """
        return try APIClient.decoder.decode(TransactionPage.self, from: Data(json.utf8))
    }

    private func row(_ id: String, date: String, kind: String = "expense", amount: Int, group: String? = nil) -> String {
        let groupJSON = group.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"\(id)","account":{"id":"a","name":"BBVA"},"kind":"\(kind)","amount_cents":\(amount),"date":"\(date)",
         "category":null,"transfer_group_id":\(groupJSON)}
        """
    }

    @Test func groupsByDayAndHidesIncomingTransferLeg() throws {
        let decoded = try page([
            row("1", date: "2026-10-27", amount: -1200),
            row("2", date: "2026-10-27", kind: "transfer", amount: -5000, group: "g"),
            row("3", date: "2026-10-27", kind: "transfer", amount: 5000, group: "g"),
            row("4", date: "2026-10-26", kind: "income", amount: 3000),
        ].joined(separator: ","))
        #expect(decoded.meta.hasMore == true)
        #expect(decoded.meta.totals.expenseCents == -500)

        let groups = DayGroup.build(decoded.data, hideIncomingTransfers: true)
        #expect(groups.map(\.date) == ["2026-10-27", "2026-10-26"])
        #expect(groups[0].items.map(\.id) == ["1", "2"])
        #expect(groups[0].totalCents == -1200)

        let withBothLegs = DayGroup.build(decoded.data, hideIncomingTransfers: false)
        #expect(withBothLegs[0].items.count == 3)
    }

    @Test func filtersBuildApiQuery() {
        var filters = TransactionFilters()
        #expect(filters.apiQuery(currentPeriodId: "now") == ["period_id": "now"])

        filters.accountIds = ["b", "a"]
        filters.kinds = [.income, .expense]
        filters.query = "  mercadona "
        filters.pendingOnly = true
        let query = filters.apiQuery(currentPeriodId: "now")
        #expect(query["account_id"] == "a,b")
        #expect(query["kind"] == "expense,income")
        #expect(query["q"] == "mercadona")
        #expect(query["status"] == "pending")
        #expect(filters.activeCount == 3)

        filters.allPeriods = true
        #expect(filters.apiQuery(currentPeriodId: "now")["period_id"] == nil)
        #expect(filters.cleared() == TransactionFilters(allPeriods: true))
    }
}
