import Foundation
import Observation

/// Loads everything Inicio shows. Each card has its own slot so one failing
/// endpoint never blanks the whole screen.
@Observable
final class HomeModel {
    enum Slot<T: Equatable>: Equatable {
        case loading, loaded(T), failed

        var value: T? {
            if case .loaded(let value) = self { value } else { nil }
        }
    }

    var modules: [AppModule]?
    var finance: Slot<FinanceSummary> = .loading
    var pending: PendingSummary?
    var notifications: Slot<[AppNotification]> = .loading
    var unreadCount = 0
    var tasks: Slot<TasksToday> = .loading
    var habits: HabitsToday?
    /// The WHOOP link and its latest scored day, for the WHOOP card (only once connected).
    var whoop: WhoopStatus?
    var whoopDay: WhoopDay?
    /// Today's calendar, for the Agenda card (only shown once a Google account is linked).
    var agenda: CalendarRange?
    var toast: String?

    private let api: APIClient
    /// Logs habits from the Inicio rings (tap, long press, "Deshacer").
    let habitActions: HabitActions

    init(api: APIClient) {
        self.api = api
        habitActions = HabitActions(api: api)
    }

    func isEnabled(_ module: String) -> Bool {
        modules?.first { $0.id == module }?.isOn ?? (module == AppModule.finance)
    }

    func load() async {
        await loadModules()
        async let finance: Void = loadFinance()
        async let pending: Void = loadPending()
        async let notifications: Void = loadNotifications()
        async let tasks: Void = isEnabled(AppModule.tasks) ? loadTasks() : ()
        async let habits: Void = isEnabled(AppModule.habits) ? loadHabits() : ()
        async let whoop: Void = isEnabled(AppModule.health) ? loadWhoop() : ()
        async let agenda: Void = isEnabled(AppModule.calendar) ? loadAgenda() : ()
        _ = await (finance, pending, notifications, tasks, habits, whoop, agenda)
    }

    func loadModules() async {
        if let envelope: DataEnvelope<[AppModule]> = try? await api.get("v1/modules") {
            modules = envelope.data
        }
    }

    func loadFinance() async {
        do {
            let summary: DataEnvelope<FinanceSummary> = try await api.get("v1/finance/summary")
            finance = .loaded(summary.data)
        } catch {
            if finance.value == nil { finance = .failed }
        }
    }

    func loadPending() async {
        if let envelope: DataEnvelope<PendingSummary> = try? await api.get("v1/pending/summary") {
            pending = envelope.data
        }
    }

    func loadNotifications() async {
        do {
            let page: NotificationsPage = try await api.get("v1/notifications", query: ["page": "1"])
            notifications = .loaded(page.data)
            unreadCount = page.meta?.unreadCount ?? page.data.filter(\.unread).count
        } catch {
            if notifications.value == nil { notifications = .failed }
        }
    }

    func loadTasks() async {
        do {
            let envelope: DataEnvelope<TasksToday> = try await api.get("v1/tasks/today")
            tasks = .loaded(envelope.data)
        } catch {
            if tasks.value == nil { tasks = .failed }
        }
    }

    func loadHabits() async {
        if let envelope: DataEnvelope<HabitsToday> = try? await api.get("v1/habits/today") {
            habits = envelope.data
        }
    }

    func loadWhoop() async {
        guard let status = try? await WhoopAPI.status(api) else { return }
        whoop = status
        guard status.account != nil else { whoopDay = nil; return }
        // The latest day with a recovery or a night: today's appears once WHOOP has scored the sleep.
        if let days = try? await WhoopAPI.days(api, from: Calendar.current.date(byAdding: .day, value: -2, to: .now)) {
            whoopDay = days.first { $0.recovery != nil || $0.sleep != nil } ?? days.first
        }
    }

    func loadAgenda() async {
        let today = CarliDate.isoDay(.now)
        if let envelope: DataEnvelope<CalendarRange> = try? await api.get("v1/calendar", query: ["from": today, "to": today]) {
            agenda = envelope.data
        }
    }

    // MARK: Actions

    func markRead(_ notification: AppNotification) async {
        let _: UnreadCount? = try? await api.post("v1/notifications/read", body: Patch(["ids": .array([.string(notification.id)])]))
        await loadNotifications()
    }

    func complete(_ task: TaskItem) async {
        do {
            let _: Empty = try await api.post("v1/tasks/tasks/\(task.id)/complete")
            toast = "\(task.title) hecha"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido completar la tarea.")
        }
        await loadTasks()
        await loadPending()
    }
}
