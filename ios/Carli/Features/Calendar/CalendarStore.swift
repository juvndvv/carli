import Foundation
import Observation

/// Calendar items cached by month, so every mode reads from the same copy and moving back
/// and forth costs no requests.
@Observable
final class CalendarStore {
    let api: APIClient

    private(set) var months: [String: CalendarRange] = [:]
    private(set) var byDay: [String: [CalendarItem]] = [:]
    private(set) var google: GoogleStatus?
    private(set) var failed: String?

    init(api: APIClient) { self.api = api }

    func isLoaded(_ key: String) -> Bool { months[key] != nil }

    func items(on day: Date) -> [CalendarItem] { byDay[CarliDate.isoDay(day)] ?? [] }

    func load(_ keys: [String], force: Bool) async {
        for key in keys where force || months[key] == nil {
            guard let bounds = CalendarLayout.bounds(ofMonth: key) else { continue }
            do {
                let envelope: DataEnvelope<CalendarRange> = try await api.get(
                    "v1/calendar",
                    query: ["from": CarliDate.isoDay(bounds.from), "to": CarliDate.isoDay(bounds.to)]
                )
                months[key] = envelope.data
                google = envelope.data.google
                failed = nil
                index()
            } catch {
                if months[key] == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
            }
        }
    }

    /// Reloads every month already seen.
    func reloadAll(also keys: [String]) async {
        let seen = Array(months.keys)
        await load(Array(Set(seen + keys)).sorted(), force: true)
    }

    /// Accounts or calendars changed: everything cached is stale.
    func reset() {
        months = [:]
        byDay = [:]
    }

    private func index() {
        var days: [String: [CalendarItem]] = [:]
        for range in months.values {
            for item in range.items { days[item.date, default: []].append(item) }
        }
        byDay = days.mapValues(CalendarLayout.sorted)
    }
}
