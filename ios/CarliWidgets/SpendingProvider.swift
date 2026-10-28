import Foundation
import WidgetKit

enum SpendingState {
    case loaded(WidgetSnapshot)
    case signedOut
    case unavailable
}

struct SpendingEntry<Intent: WidgetConfigurationIntent>: TimelineEntry {
    var date: Date
    var state: SpendingState
    var configuration: Intent
}

/// Fetches the snapshot from the API on every reload (timeline, app or push) and falls back to the last one it saw.
struct SpendingProvider<Intent: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    private static var refreshInterval: TimeInterval { 30 * 60 }

    func placeholder(in context: Context) -> SpendingEntry<Intent> {
        SpendingEntry(date: .now, state: .loaded(.sample), configuration: Intent())
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SpendingEntry<Intent> {
        if context.isPreview { return SpendingEntry(date: .now, state: .loaded(.sample), configuration: configuration) }
        return SpendingEntry(date: .now, state: await SnapshotCache.load(), configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SpendingEntry<Intent>> {
        let now = Date.now
        let entry = SpendingEntry(date: now, state: await SnapshotCache.load(), configuration: configuration)
        // "Hoy" has to roll over at midnight even when nothing else changes.
        let midnight = CarliDate.calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60 + 60)
        let next = min(now.addingTimeInterval(Self.refreshInterval), midnight)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

/// The last good snapshot, kept in the extension's own defaults for when the network is not there.
enum SnapshotCache {
    private static let key = "widget.snapshot"

    static func load() async -> SpendingState {
        do {
            let snapshot = try await WidgetAPI.snapshot()
            if let data = try? JSONEncoder().encode(snapshot) { UserDefaults.standard.set(data, forKey: key) }
            return .loaded(snapshot)
        } catch .signedOut {
            UserDefaults.standard.removeObject(forKey: key)
            return .signedOut
        } catch {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let cached = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
            else { return .unavailable }
            return .loaded(cached)
        }
    }
}
