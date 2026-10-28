import Foundation
import Testing
@testable import Carli

struct FinanceSummaryTests {
    @Test func donutKeepsCategorySlotsAndGroupsTheRest() {
        let groups = (1...10).map { CategoryGroup(name: "C\($0)", color: $0 == 1 ? "c5" : nil, amountCents: 1000 - $0) }
        let slices = DonutSlice.build(groups)
        #expect(slices.count == 8)
        #expect(slices[0].slot == 5)
        #expect(slices[1].slot == 1)
        #expect(slices.last?.label == "Otras categorías")
        #expect(Set(slices.map(\.id)).count == slices.count)
        #expect(slices.last?.slot == nil)
    }

    @Test func percentDropsTrailingZero() {
        #expect(Percent.format(1200) == "12 %")
        #expect(Percent.format(1234, signed: true) == "+12,3 %")
        #expect(Percent.format(-50) == "−0,5 %")
    }

    @Test func ringsFromDashboard() throws {
        let json = """
        {"period":{"id":"p","name":"Octubre","start_date":"2026-10-01","days_remaining":0,"is_current":false},
         "income_cents":200000,"expense_cents":150000,"savings_cents":50000,"net_worth_cents":0,
         "by_category":[],"history":[],"upcoming":[],"recent_transactions":[],
         "budgets":{"top":[],"totals":{"budgeted_cents":100000,"spent_cents":120000,"remaining_cents":-20000,"percent_bp":12000}}}
        """
        let data = try APIClient.decoder.decode(Dashboard.self, from: Data(json.utf8))
        let rings = RingFigures(data, savingsTargetPercent: 20)
        #expect(rings.available == 0)
        #expect(rings.savings == 1.25)
        #expect(rings.pace == 1.2)
        #expect(rings.aheadOfPlan)
    }
}
