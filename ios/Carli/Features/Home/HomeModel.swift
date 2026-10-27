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
    var notes: NotesSnapshot?
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
        async let notes: Void = isEnabled(AppModule.notes) ? loadNotes() : ()
        _ = await (finance, pending, notifications, tasks, habits, notes)
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

    func loadNotes() async {
        if let envelope: DataEnvelope<NotesSnapshot> = try? await api.get("v1/notes/snapshot") {
            notes = envelope.data
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

    /// Ticks a shopping item through the notes sync endpoint, as the Flutter app does offline.
    func check(_ item: NoteItem) async {
        struct Payload: Encodable { var id: String, checked: Bool }
        struct Operation: Encodable { var id: String, type: String, at: String, payload: Payload }
        struct Body: Encodable { var operations: [Operation] }
        let payload = Payload(id: item.id, checked: true)
        let operation = Operation(id: UUID().uuidString.lowercased(), type: "item.upsert",
                                  at: ISO8601DateFormatter().string(from: .now), payload: payload)
        do {
            let _: Empty = try await api.post("v1/notes/sync", body: Body(operations: [operation]))
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido marcar \(item.text).")
        }
        await loadNotes()
    }
}
