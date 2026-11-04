import Foundation
import Testing
@testable import Carli

struct CalendarTests {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func rangeDecodesEventsAndCarliItems() throws {
        let range: CalendarRange = try decode(#"""
        {"from":"2026-11-02","to":"2026-11-08","google":{"accounts":1,"reconnect":[],"synced_at":"2026-11-03T10:00:00+01:00"},
         "items":[
          {"source":"google","id":"e1","title":"Dentista","date":"2026-11-04","time":"09:30","end_date":null,"end_time":"10:15","all_day":false,"done":false,
           "subtitle":"Calle Mayor 3","color":"#9fe1e7","url":null,
           "meta":{"event_id":"e1","calendar":"juanda@jotade.io","html_link":"https://calendar.google.com/e","start_date":"2026-11-04","last_date":"2026-11-04"}},
          {"source":"tasks","id":"t1","title":"Llamar","date":"2026-11-04","time":null,"end_date":null,"end_time":null,"all_day":true,"done":true,
           "subtitle":null,"color":null,"url":"/tareas/tarea/t1","meta":{"task_id":"t1","important":true,"overdue":false}},
          {"source":"habits","id":"habits:2026-11-03","title":"Hábitos","date":"2026-11-03","time":null,"end_date":null,"end_time":null,"all_day":true,
           "done":false,"subtitle":"1 de 2","color":null,"url":"/habitos/hoy","meta":{"done":1,"total":2}},
          {"source":"nuevo","id":"x","title":"Algo nuevo","date":"2026-11-03","time":null,"end_date":null,"end_time":null,"all_day":true,"done":false,
           "subtitle":null,"color":null,"url":null,"meta":{}}
         ]}
        """#)
        #expect(range.items.count == 4)
        #expect(range.items[0].kind == .google)
        #expect(range.items[0].timeRange == "09:30 – 10:15")
        #expect(range.items[0].tint != nil)
        #expect(range.items[0].meta?.htmlLink == "https://calendar.google.com/e")
        #expect(range.items[1].meta?.taskId == "t1")
        #expect(range.items[1].timeRange == nil)
        #expect(range.items[2].meta?.total == 2)
        // Unknown sources from a newer server are ignored, not a decoding error.
        #expect(range.items[3].kind == nil)
    }

    @Test func weeksStartOnMonday() {
        let wednesday = CarliDate.day("2026-11-04")!
        let sunday = CarliDate.day("2026-11-08")!
        #expect(CarliDate.isoDay(CalendarLayout.monday(of: wednesday)) == "2026-11-02")
        #expect(CarliDate.isoDay(CalendarLayout.monday(of: sunday)) == "2026-11-02")
    }

    @Test func googleCallbackOutcomes() {
        if case .connected = GoogleAuth.outcome(URL(string: "carli://calendar/google?account=a1")!) {} else { Issue.record("expected connected") }
        if case .failed(let message) = GoogleAuth.outcome(URL(string: "carli://calendar/google?error=permisos")!) {
            #expect(message.contains("Google Calendar"))
        } else {
            Issue.record("expected failure")
        }
    }

    @Test func calendarLinksOpenInicio() {
        #expect(AppLink.parse("/calendario")?.tab == "home")
        #expect(AppLink.parse("/calendario")?.steps == [.home(.calendar)])
        #expect(AppLink.parse("/ajustes/calendarios")?.steps == [.home(.settings), .settings(.calendars)])
    }

    private func item(_ id: String, _ time: String?, _ end: String? = nil, allDay: Bool = false) -> CalendarItem {
        CalendarItem(source: "google", id: id, title: id, date: "2026-11-04", time: time, endTime: end,
                     allDay: allDay, done: false, subtitle: nil, color: nil, url: nil, meta: nil)
    }

    @Test func overlappingItemsShareLanes() {
        let placed = CalendarLayout.place([
            item("a", "09:00", "10:00"),
            item("b", "09:30", "11:00"),
            item("c", "10:00", "10:30"),
            item("d", "12:00"),
            item("e", nil, allDay: true),
        ])
        let lanes = Dictionary(uniqueKeysWithValues: placed.map { ($0.item.id, "\($0.lane)/\($0.lanes)") })
        #expect(placed.count == 4)
        #expect(lanes["a"] == "0/2")
        #expect(lanes["b"] == "1/2")
        #expect(lanes["c"] == "0/2")
        #expect(lanes["d"] == "0/1")
        #expect(placed.first { $0.item.id == "d" }?.end == 12 * 60 + 30)
    }

    @Test func modesCoverTheRightDays() throws {
        let wednesday = try #require(CarliDate.day("2026-11-04"))
        let week = CalendarLayout.days(.week, around: wednesday)
        #expect(week.count == 7)
        #expect(CarliDate.isoDay(week[0]) == "2026-11-02")
        #expect(CalendarLayout.days(.threeDays, around: wednesday).map(CarliDate.isoDay) == ["2026-11-04", "2026-11-05", "2026-11-06"])
        let month = CalendarLayout.days(.month, around: wednesday)
        #expect(month.count == 42)
        #expect(CarliDate.isoDay(month[0]) == "2026-10-26")
        #expect(CalendarLayout.monthKeys(for: month) == ["2026-10", "2026-11", "2026-12"])
        #expect(CalendarLayout.monthKeys(for: week) == ["2026-11"])
        #expect(CarliDate.isoDay(CalendarLayout.step(.month, from: wednesday, by: 1)) == "2026-12-01")
        #expect(CarliDate.isoDay(CalendarLayout.step(.threeDays, from: wednesday, by: -1)) == "2026-11-01")
        #expect(CalendarLayout.bounds(ofMonth: "2027-02").map { CarliDate.isoDay($0.to) } == "2027-02-28")
    }

    @Test func titlesFollowTheVisibleDays() throws {
        let now = try #require(CarliDate.day("2026-11-04"))
        let endOfOctober = try #require(CarliDate.day("2026-10-30"))
        #expect(CalendarLayout.title(.month, selected: now, now: now) == "Noviembre")
        #expect(CalendarLayout.title(.week, selected: endOfOctober, now: now) == "Oct – nov")
        #expect(CalendarLayout.title(.year, selected: now, now: now) == "2026")
        let nextYear = try #require(CarliDate.day("2027-01-10"))
        #expect(CalendarLayout.title(.day, selected: nextYear, now: now) == "Enero 2027")
    }
}
