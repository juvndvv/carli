import Foundation
import Testing
@testable import Carli

struct BudgetsTests {
    @Test func parsesTypedAmounts() {
        #expect(Money.parse("12") == 1200)
        #expect(Money.parse("12,5") == 1250)
        #expect(Money.parse("1.234,56 €") == 123456)
        #expect(Money.parse("12.50") == 1250)
        #expect(Money.parse("") == nil)
        #expect(Money.parse("abc") == nil)
        #expect(Money.input(123450) == "1234,5" || Money.input(123450) == "1234,50")
        #expect(Money.input(5000) == "50")
    }

    @Test func editorSendsOnlyChangesWithExplicitNull() throws {
        let json = """
        {"data":[{"id":"b1","category_id":"food","category":{"name":"Comida","sort_key":1},"amount_cents":20000,"rollover":false,
                  "available_cents":20000,"spent_cents":5000,"remaining_cents":15000,"status":"ok"}],
         "meta":{"period":{"id":"p","name":"Octubre"},"totals":{"budgeted_cents":20000,"spent_cents":5000,"remaining_cents":15000}}}
        """
        let overview = try APIClient.decoder.decode(BudgetOverview.self, from: Data(json.utf8))
        #expect(overview.data[0].usageLabel == "25 %")

        let categories = [FinanceCategory(id: "food", name: "Comida", kind: "expense", icon: nil, archived: false,
                                          children: [FinanceCategory(id: "bar", name: "Bares", kind: "expense", icon: nil, archived: false, children: nil)]),
                          FinanceCategory(id: "pay", name: "Nómina", kind: "income", icon: nil, archived: false, children: nil)]
        var lines = BudgetEditorLine.build(categories: categories, rows: overview.data)
        #expect(lines.map(\.categoryId) == ["food", "bar"])
        #expect(lines[0].amountText == "200")
        #expect(BudgetEditorLine.changes(lines).isEmpty)

        lines[0].amountText = ""
        lines[1].amountText = "30"
        let changes = BudgetEditorLine.changes(lines)
        #expect(changes == [BudgetChange(categoryId: "food", amountCents: nil, rollover: false),
                            BudgetChange(categoryId: "bar", amountCents: 3000, rollover: false)])
        let encoded = String(decoding: try APIClient.encoder.encode(changes[0]), as: UTF8.self)
        #expect(encoded.contains("\\"amount_cents\\":null"))
    }
}
