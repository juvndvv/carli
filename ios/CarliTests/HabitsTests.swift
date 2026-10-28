import Foundation
import Testing
@testable import Carli

struct HabitsTests {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func numbersDropTrailingZeros() {
        #expect(HabitFormat.number(8) == "8")
        #expect(HabitFormat.number(1.5) == "1,5")
        #expect(HabitFormat.number(0.25) == "0,25")
    }

    @Test func avoidWithoutAllowanceShowsCleanStreak() throws {
        let habit: HabitToday = try decode(#"{"id":"h","name":"Fumar","kind":"avoid","target":0,"value":0,"streak":3,"period":"day"}"#)
        #expect(habit.valueLabel == "3 días sin")
        #expect(habit.nextTapValue == 1)
    }

    @Test func weeklyGoalLineCountsDaysLeft() throws {
        let habit: HabitToday = try decode(#"{"id":"h","name":"Correr","kind":"check","period":"week","target":3,"value":1,"days_left":2,"goal_text":"3 veces por semana"}"#)
        #expect(HabitFormat.goalLine(habit) == "3 veces por semana · quedan 2 días")
        #expect(habit.valueLabel == "1 de 3")
    }

    @Test func onlyPlainDailyOrWeeklyTemplatesConvert() {
        #expect(HabitConversion.canConvert(rrule: "FREQ=DAILY"))
        #expect(HabitConversion.canConvert(rrule: "FREQ=WEEKLY;BYDAY=MO,WE"))
        #expect(!HabitConversion.canConvert(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO"))
        #expect(!HabitConversion.canConvert(rrule: "FREQ=MONTHLY;BYMONTHDAY=1"))
        #expect(!HabitConversion.canConvert(rrule: "FREQ=WEEKLY;BYDAY=1MO"))
        #expect(!HabitConversion.canConvert(rrule: nil))
    }

    @Test func progressYearRowsReadMonthCells() throws {
        let row: ProgressRow = try decode(#"{"id":"h","name":"Leer","cells":[{"month":"2026-01","consistency":80},{"month":"2026-02","consistency":null}]}"#)
        #expect(row.cells.isEmpty)
        #expect(row.monthCells == [80, nil])
    }
}
