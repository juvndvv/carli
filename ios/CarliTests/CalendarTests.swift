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
        #expect(CarliDate.isoDay(CalendarView.monday(of: wednesday)) == "2026-11-02")
        #expect(CarliDate.isoDay(CalendarView.monday(of: sunday)) == "2026-11-02")
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
        #expect(AppLink.parse("/calendario")?.section == "calendar")
        #expect(AppLink.parse("/ajustes/calendarios")?.steps == [.home(.settings), .settings(.calendars)])
    }
}
