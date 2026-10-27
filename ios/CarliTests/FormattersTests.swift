import Foundation
import Testing
@testable import Carli

struct MoneyTests {
    @Test func groupsThousandsWithSpanishSeparators() {
        #expect(Money.format(123_456_78) == "123.456,78\u{00A0}€")
        #expect(Money.format(5) == "0,05\u{00A0}€")
    }

    @Test func negativeUsesTrueMinus() {
        #expect(Money.format(-1050) == "−10,50\u{00A0}€")
        #expect(Money.format(1050, .signed) == "+10,50\u{00A0}€")
    }
}

struct HomeDecodingTests {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func decodesFinanceSummary() throws {
        let envelope: DataEnvelope<FinanceSummary> = try decode("""
        {"data":{"period":{"id":"p1","name":"Octubre","short_name":"oct","days_remaining":4},
         "spent_cents":12345,"net_worth_cents":-500,
         "budget":{"budgeted_cents":100000,"spent_cents":12345,"remaining_cents":87655,"percent_bp":1234,"projected_cents":0}}}
        """)
        #expect(envelope.data.period.shortName == "oct")
        #expect(envelope.data.budget.percentBp == 1234)
    }

    @Test func tasksHeadline() throws {
        let view: TasksToday = try decode("""
        {"date":"2026-10-27","overdue":[{"id":"a","title":"Pagar","overdue":true}],
         "today":[{"id":"b","title":"Correr"},{"id":"c","title":"Leer"}],"done":[],"progress":{"done":0,"total":3}}
        """)
        #expect(view.headline == "2 tareas para hoy · 1 vencida")
    }

    @Test func habitWithMissingNumbersDefaultsToZero() throws {
        let habit: HabitToday = try decode(#"{"id":"h","name":"Agua","icon":"droplet","kind":"quantity","unit":"vasos","target":8,"value":3}"#)
        #expect(habit.valueLabel == "3 / 8 vasos")
        #expect(habit.nextTapValue == 1)
    }
}
