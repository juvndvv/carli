import SwiftUI

/// The inbox: pages of notifications with read/unread and delete, optimistic and then confirmed.
@Observable
final class NotificationsModel {
    var items: [AppNotification] = []
    var nextPage: Int?
    var unread = 0
    var loaded = false
    var failed: String?
    var loadingMore = false
    var toast: String?

    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var hasRead: Bool { items.contains { !$0.unread } || nextPage != nil }

    func load() async {
        do {
            let page: NotificationsPage = try await api.get("v1/notifications", query: ["page": "1"])
            items = page.data
            nextPage = page.nextPage
            unread = page.meta?.unreadCount ?? page.data.filter(\.unread).count
            failed = nil
        } catch {
            if !loaded { failed = error.apiMessage(fallback: "Comprueba la conexión e inténtalo de nuevo.") }
        }
        loaded = true
    }

    func loadMore() async {
        guard let next = nextPage, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page: NotificationsPage = try await api.get("v1/notifications", query: ["page": "\(next)"])
            let known = Set(items.map(\.id))
            items += page.data.filter { !known.contains($0.id) }
            nextPage = page.nextPage
            if let count = page.meta?.unreadCount { unread = count }
        } catch {
            toast = "No se han podido cargar más notificaciones."
        }
    }

    func markRead(_ ids: [String]? = nil) async {
        let previous = items
        let now = ISO8601DateFormatter().string(from: .now)
        items = items.map { item in
            var item = item
            if item.unread && (ids?.contains(item.id) ?? true) { item.readAt = now }
            return item
        }
        await write("v1/notifications/read", ids.map { ["ids": .array($0.map(JSONValue.string))] } ?? ["all": .bool(true)],
                    previous: previous, error: "No se han podido marcar como leídas.")
    }

    func markUnread(_ id: String) async {
        let previous = items
        items = items.map { item in
            var item = item
            if item.id == id { item.readAt = nil }
            return item
        }
        await write("v1/notifications/unread", ["ids": .array([.string(id)])],
                    previous: previous, error: "No se ha podido marcar como no leída.")
    }

    func delete(_ id: String) async {
        let previous = items
        items.removeAll { $0.id == id }
        await write("v1/notifications/delete", ["ids": .array([.string(id)])],
                    previous: previous, error: "No se han podido borrar las notificaciones.")
    }

    func deleteRead() async {
        let previous = items
        items.removeAll { !$0.unread }
        await write("v1/notifications/delete", ["read": .bool(true)], previous: previous,
                    error: "No se han podido borrar las notificaciones.")
        await load()
    }

    func deleteAll() async {
        let previous = items
        items = []
        nextPage = nil
        await write("v1/notifications/delete", ["all": .bool(true)], previous: previous,
                    error: "No se han podido borrar las notificaciones.")
    }

    private func write(_ path: String, _ body: [String: JSONValue], previous: [AppNotification], error message: String) async {
        do {
            let response: UnreadCount = try await api.post(path, body: Patch(body))
            unread = response.unreadCount ?? items.filter(\.unread).count
        } catch {
            items = previous
            toast = message
        }
        NotificationCenter.default.post(name: .notificationsChanged, object: nil)
    }
}

struct NotificationsView: View {
    @State var model: NotificationsModel
    @Environment(AppRouter.self) private var router
    @State private var confirmingDeleteAll = false

    var body: some View {
        List {
            if !model.loaded {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            } else if let failed = model.failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las notificaciones", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await model.load() } }.buttonStyle(.glass)
                }
                .listRowBackground(Color.clear)
            } else if model.items.isEmpty {
                ContentUnavailableView("No tienes notificaciones", systemImage: "bell",
                                       description: Text("Aquí aparecerán los avisos de presupuestos, recurrentes y pendientes."))
                    .listRowBackground(Color.clear)
            } else {
                let unread = model.items.filter(\.unread)
                let read = model.items.filter { !$0.unread }
                if !unread.isEmpty {
                    Section("Sin leer") { ForEach(unread) { row($0) } }
                }
                if !read.isEmpty {
                    Section("Leídas") { ForEach(read) { row($0) } }
                }
                Section {
                    if model.nextPage != nil {
                        Button {
                            Task { await model.loadMore() }
                        } label: {
                            if model.loadingMore { ProgressView().frame(maxWidth: .infinity) } else {
                                Text("Cargar más").frame(maxWidth: .infinity)
                            }
                        }
                        .foregroundStyle(CarliColor.text)
                    }
                } footer: {
                    Text("Desliza para marcar como leída o borrar.")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if model.unread > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Marcar como leídas", systemImage: "checkmark.circle") { Task { await model.markRead() } }
                }
            }
            if !model.items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if model.hasRead {
                            Button("Borrar leídas", systemImage: "checkmark.circle") { Task { await model.deleteRead() } }
                        }
                        Button("Borrar todas", systemImage: "trash", role: .destructive) { confirmingDeleteAll = true }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Borrar notificaciones")
                }
            }
        }
        .confirmationDialog("¿Borrar todas las notificaciones?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Borrar todas", role: .destructive) { Task { await model.deleteAll() } }
        } message: {
            Text("No se pueden recuperar.")
        }
        .refreshable { await model.load() }
        .task { await model.load() }
        .carliToast($model.toast)
    }

    private func row(_ item: AppNotification) -> some View {
        Button {
            if item.unread { Task { await model.markRead([item.id]) } }
            router.open(url: item.url)
        } label: {
            HStack(spacing: CarliSpace.s12) {
                Image(systemName: item.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(item.unread ? CarliColor.text : CarliColor.text3)
                    .frame(width: 36, height: 36)
                    .background(CarliColor.surface2, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body.weight(item.unread ? .semibold : .regular))
                        .foregroundStyle(item.unread ? CarliColor.text : CarliColor.text2)
                    Text(item.subtitleLine)
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text3)
                }
                Spacer(minLength: 0)
                if item.unread {
                    Circle().fill(CarliColor.text).frame(width: 8, height: 8).accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(item.unread ? "Sin leer" : "")
        .swipeActions(edge: .leading) {
            if item.unread {
                Button("Leída", systemImage: "checkmark") { Task { await model.markRead([item.id]) } }.tint(CarliColor.neutralFill)
            } else {
                Button("No leída", systemImage: "circle.inset.filled") { Task { await model.markUnread(item.id) } }.tint(CarliColor.neutralFill)
            }
        }
        .swipeActions(edge: .trailing) {
            DeleteSwipeButton("Borrar") { Task { await model.delete(item.id) } }
        }
    }
}
