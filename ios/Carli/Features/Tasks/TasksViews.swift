import SwiftUI

struct TaskRoute: Hashable { var id: String }
struct TaskListRoute: Hashable { var id: String }
struct TemplateRoute: Hashable { var id: String? ; var seed: TemplateSeed? = nil }
struct TasksSettingsRoute: Hashable {}
struct DoneTasksRoute: Hashable {}
struct ArchivedListsRoute: Hashable {}

/// What "Repetir" in the new-task sheet carries over into a new template.
struct TemplateSeed: Hashable {
    var title = ""
    var notes = ""
    var listId: String?
    var dueTime: String?
    var important = false
    var start: Date?
}

extension View {
    /// Pages every Tareas section can push.
    func tasksDestinations(api: APIClient) -> some View {
        navigationDestination(for: TaskRoute.self) { TaskDetailView(api: api, taskId: $0.id) }
            .navigationDestination(for: TaskListRoute.self) { ListDetailView(api: api, listId: $0.id) }
            .navigationDestination(for: TemplateRoute.self) { TemplateEditorView(api: api, templateId: $0.id, seed: $0.seed ?? TemplateSeed()) }
            .navigationDestination(for: TasksSettingsRoute.self) { _ in TasksSettingsView(api: api) }
            .navigationDestination(for: DoneTasksRoute.self) { _ in DoneTasksView(api: api) }
            .navigationDestination(for: ArchivedListsRoute.self) { _ in ArchivedListsView(api: api) }
    }

    /// Reloads when any task write happens anywhere.
    func onTasksChanged(_ reload: @escaping () async -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .tasksChanged)) { _ in Task { await reload() } }
    }
}

/// Shared check / postpone plumbing for screens that list tasks.
@Observable
final class TaskListActions {
    let actions: TaskActions
    var undo: UndoOffer?
    var toast: String?
    var postponing: TaskItem?

    init(api: APIClient) {
        actions = TaskActions(api: api)
    }

    func toggle(_ item: TaskItem) {
        Task {
            do {
                if item.isDone {
                    try await actions.reopen(item)
                } else {
                    try await actions.complete(item)
                    undo = UndoOffer(text: "\(item.title) hecha") { [actions] in try? await actions.reopen(item) }
                }
            } catch {
                toast = error.apiMessage(fallback: item.isDone ? "No se ha podido deshacer." : "No se ha podido completar la tarea.")
            }
        }
    }

    func postpone(_ item: TaskItem, to date: Date) {
        Task {
            do { try await actions.postpone(item, to: date) } catch {
                toast = error.apiMessage(fallback: "No se ha podido posponer la tarea.")
            }
        }
    }
}

private struct TaskListModifiers: ViewModifier {
    @Bindable var handler: TaskListActions

    func body(content: Content) -> some View {
        content
            .sheet(item: $handler.postponing) { item in
                PostponeSheet(from: item.dueDate.flatMap(CarliDate.day), includeToday: item.isOverdue) { date in
                    handler.postpone(item, to: date)
                }
            }
            .undoBar($handler.undo, seconds: 4)
            .carliToast($handler.toast)
    }
}

extension View {
    func taskListActions(_ handler: TaskListActions) -> some View { modifier(TaskListModifiers(handler: handler)) }
}

/// A titled inset-grouped section of task rows.
private struct TaskSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        if let title {
            Section { content } header: {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(CarliColor.text).textCase(nil)
            }
        } else {
            Section { content }
        }
    }
}

// MARK: Hoy

struct TasksTodayView: View {
    let api: APIClient
    var openHabits: (() -> Void)?

    @State private var view: TasksToday?
    @State private var failed: String?
    @State private var settings: TasksSettings?
    @State private var habits: [HabitToday] = []
    @State private var showDone = false
    @State private var adding = false
    @State private var handler: TaskListActions
    @State private var habitActions: HabitActions

    init(api: APIClient, openHabits: (() -> Void)? = nil) {
        self.api = api
        self.openHabits = openHabits
        _handler = State(initialValue: TaskListActions(api: api))
        _habitActions = State(initialValue: HabitActions(api: api))
    }

    var body: some View {
        List {
            if let view {
                content(view)
            } else if let failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las tareas", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: TasksSettingsRoute()) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Ajustes de Tareas")
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onTasksChanged { await load() }
        .onHabitsChanged { habits = await HabitsForTasks.load(api) }
        .tasksDestinations(api: api)
        .taskListActions(handler)
        .habitActions(habitActions)
        .sheet(isPresented: $adding) { NewTaskSheet(api: api) }
    }

    @ViewBuilder
    private func content(_ view: TasksToday) -> some View {
        let done = view.progress?.done ?? 0
        let total = view.progress?.total ?? 0
        Section {
            Text(CarliDate.day(view.date).map(CarliDate.long) ?? "")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: 0, trailing: 0))
            if total > 0 || !view.overdue.isEmpty {
                HStack(spacing: CarliSpace.s16) {
                    ActivityRing(progress: total == 0 ? 0 : Double(done) / Double(total), color: CarliColor.rings[0],
                                 lineWidth: 10)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(done) de \(total)").font(.title2.weight(.bold)).monospacedDigit()
                        Text("hechas hoy").font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                    Spacer()
                    if !view.overdue.isEmpty {
                        Text(view.overdue.count == 1 ? "1 vencida" : "\(view.overdue.count) vencidas")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(CarliColor.negative)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }

        if !habits.isEmpty {
            Section {
                Button { openHabits?() } label: {
                    HStack {
                        Text("Hábitos").fontWeight(.semibold)
                            + Text(" · \(habits.count == 1 ? "queda 1" : "quedan \(habits.count)")").foregroundStyle(CarliColor.text2)
                        Spacer()
                        Text("Ver todos").font(.footnote).foregroundStyle(CarliColor.brandInk)
                    }
                    .foregroundStyle(CarliColor.text)
                }
                HabitRingStrip(habits: habits, actions: habitActions)
                    .listRowInsets(EdgeInsets(top: CarliSpace.s8, leading: CarliSpace.s16, bottom: CarliSpace.s12, trailing: CarliSpace.s16))
            }
        }

        if !view.overdue.isEmpty {
            TaskSection(title: "Vencidas") { rows(view.overdue) }
        }
        TaskSection(title: "Hoy") {
            if view.today.isEmpty {
                ContentUnavailableView {
                    Label(done > 0 ? "Todo hecho por hoy" : "Nada para hoy", systemImage: "checkmark.circle")
                } description: {
                    Text(done > 0 ? "Has terminado lo que tenías para hoy." : "Apunta algo con el botón + o mira lo que viene en Próximas.")
                } actions: {
                    Button("Nueva tarea") { adding = true }.buttonStyle(.glass)
                }
            } else {
                rows(view.today)
            }
        }
        if settings?.showsDone ?? true, let doneItems = view.done, !doneItems.isEmpty {
            Section {
                Button {
                    withAnimation { showDone.toggle() }
                } label: {
                    HStack {
                        Text("Hechas hoy · \(doneItems.count)").foregroundStyle(CarliColor.text2)
                        Spacer()
                        Image(systemName: showDone ? "chevron.up" : "chevron.down").foregroundStyle(CarliColor.text2)
                    }
                }
                if showDone { rows(doneItems, postponable: false) }
            }
        }
    }

    private func rows(_ items: [TaskItem], postponable: Bool = true) -> some View {
        ForEach(items) { item in
            NavigationLink(value: TaskRoute(id: item.id)) {
                TaskRowView(item: item, postponable: postponable, toggle: { handler.toggle(item) },
                            postpone: { handler.postponing = item })
            }
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<TasksToday> = try await api.get("v1/tasks/today")
            view = envelope.data
            failed = nil
        } catch {
            if view == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
        settings = await ModuleSettings.load(api, module: AppModule.tasks, as: TasksSettings.self)
        habits = await HabitsForTasks.load(api)
    }
}

// MARK: Próximas

struct TasksUpcomingView: View {
    let api: APIClient

    @State private var days: [UpcomingDay]?
    @State private var failed: String?
    @State private var occurrence: TaskOccurrence?
    @State private var handler: TaskListActions
    @State private var editTemplate: String?

    init(api: APIClient) {
        self.api = api
        _handler = State(initialValue: TaskListActions(api: api))
    }

    var body: some View {
        List {
            if let days {
                Section {
                    Text("Próximos 14 días").font(.footnote).foregroundStyle(CarliColor.text2)
                    WeekStrip(days: Array(days.prefix(7)))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: CarliSpace.s4, trailing: CarliSpace.s4))
                let busy = days.filter { !$0.isEmpty }
                if busy.isEmpty {
                    ContentUnavailableView("Nada en las próximas dos semanas", systemImage: "calendar",
                                           description: Text("Las tareas con fecha y las plantillas que se repiten aparecerán aquí."))
                }
                ForEach(busy) { day in
                    Section {
                        ForEach(day.tasks) { item in
                            NavigationLink(value: TaskRoute(id: item.id)) {
                                TaskRowView(item: item, toggle: { handler.toggle(item) }, postpone: { handler.postponing = item })
                            }
                        }
                        ForEach(day.occurrences) { occurrence in
                            Button { self.occurrence = occurrence } label: { OccurrenceRow(occurrence: occurrence) }
                        }
                    } header: {
                        dayHeader(day.date)
                    }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se ha podido cargar la agenda", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .refreshable { await load() }
        .task { await load() }
        .onTasksChanged { await load() }
        .tasksDestinations(api: api)
        .taskListActions(handler)
        .navigationDestination(item: $editTemplate) { TemplateEditorView(api: api, templateId: $0, seed: TemplateSeed()) }
        .confirmationDialog(occurrence?.title ?? "", isPresented: Binding(get: { occurrence != nil }, set: { if !$0 { occurrence = nil } }),
                            titleVisibility: .visible, presenting: occurrence) { occurrence in
            Button("Saltar esta vez (\(CarliDate.day(occurrence.date).map(TaskDates.weekdayShort) ?? occurrence.date))") {
                Task { await skip(occurrence) }
            }
            Button("Editar plantilla") { editTemplate = occurrence.templateId }
        } message: { occurrence in
            Text(occurrence.frequencyText ?? "")
        }
    }

    private func dayHeader(_ iso: String) -> some View {
        let date = CarliDate.day(iso) ?? .now
        let offset = TaskDates.offset(date)
        let title = offset == 0 ? "Hoy" : offset == 1 ? "Mañana" : TaskDates.weekdaysLongMondayFirst[FrequencyDraft.isoWeekday(date) - 1].capitalizedFirst
        return (Text(title).font(.title3.weight(.bold)).foregroundStyle(CarliColor.text)
            + Text("  \(CarliDate.short(date))").font(.body).foregroundStyle(CarliColor.text2))
            .textCase(nil)
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[UpcomingDay]> = try await api.get("v1/tasks/upcoming")
            days = envelope.data
            failed = nil
        } catch {
            if days == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }

    private func skip(_ occurrence: TaskOccurrence) async {
        do {
            try await handler.actions.skipOccurrence(templateId: occurrence.templateId, date: occurrence.date)
            handler.undo = UndoOffer(text: "\(occurrence.title): saltada esta vez") { [handler] in
                try? await handler.actions.unskipOccurrence(templateId: occurrence.templateId, date: occurrence.date)
            }
        } catch {
            handler.toast = error.apiMessage(fallback: "No se ha podido saltar la fecha.")
        }
    }
}

private struct WeekStrip: View {
    var days: [UpcomingDay]

    var body: some View {
        HStack {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let date = CarliDate.day(day.date) ?? .now
                let first = index == 0
                VStack(spacing: 2) {
                    Text(TaskDates.weekdaysMondayFirst[FrequencyDraft.isoWeekday(date) - 1]).font(.caption)
                        .foregroundStyle(first ? CarliColor.bg : CarliColor.text2)
                    Text("\(CarliDate.calendar.component(.day, from: date))").font(.headline).monospacedDigit()
                        .foregroundStyle(first ? CarliColor.bg : CarliColor.text)
                    Circle().fill(day.isEmpty ? .clear : (first ? CarliColor.bg : CarliColor.text3)).frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CarliSpace.s8)
                .background(first ? CarliColor.text : .clear, in: .rect(cornerRadius: 14))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(CarliDate.long(date))\(day.isEmpty ? "" : ", con tareas")")
            }
        }
    }
}

private struct OccurrenceRow: View {
    var occurrence: TaskOccurrence

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.title).foregroundStyle(CarliColor.text2)
                Label([occurrence.frequencyText, occurrence.list.name, occurrence.dueTime].compactMap { $0 }.joined(separator: " · "),
                      systemImage: "repeat")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .lineLimit(1)
            }
            Spacer()
            CarliBadge(label: "Programada")
        }
        .accessibilityLabel("\(occurrence.title), programada")
    }
}

// MARK: Listas

struct TaskListsView: View {
    let api: APIClient

    @State private var lists: [TaskList]?
    @State private var failed: String?
    @State private var naming = false
    @State private var newName = ""
    @State private var reordering = false
    @State private var toast: String?

    var body: some View {
        List {
            if let lists {
                let inbox = lists.filter(\.isInbox)
                let own = lists.filter { !$0.isInbox }
                let open = lists.reduce(0) { $0 + $1.openCount }
                Text(open == 1 ? "1 abierta" : "\(open) abiertas")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .listRowBackground(Color.clear)
                if !inbox.isEmpty {
                    Section { ForEach(inbox) { row($0, subtitle: "Lo apuntado sin lista") } }
                }
                Section {
                    if own.isEmpty {
                        Button { naming = true } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Crear una lista").foregroundStyle(CarliColor.text)
                                    Text("Agrupa tareas de casa, trabajo o la compra").font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                            } icon: { Image(systemName: "plus") }
                        }
                    } else {
                        ForEach(own) { row($0) }
                    }
                } header: {
                    HStack {
                        Text("Mis listas")
                        Spacer()
                        if own.count > 1 {
                            Button("Ordenar") { reordering = true }.font(.footnote.weight(.semibold)).textCase(nil)
                        }
                    }
                }
                Section {
                    NavigationLink(value: DoneTasksRoute()) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Hechas")
                                Text("Registro de lo completado").font(.footnote).foregroundStyle(CarliColor.text2)
                            }
                        } icon: { Image(systemName: "checkmark.circle") }
                    }
                    NavigationLink(value: ArchivedListsRoute()) { Label("Archivadas", systemImage: "archivebox") }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las listas", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nueva lista", systemImage: "text.badge.plus") { naming = true }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onTasksChanged { await load() }
        .tasksDestinations(api: api)
        .alert("Nueva lista", isPresented: $naming) {
            TextField("Casa, Personal, Compra…", text: $newName)
            Button("Cancelar", role: .cancel) { newName = "" }
            Button("Guardar") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                newName = ""
                guard !name.isEmpty else { return }
                Task {
                    do { try await TaskActions(api: api).createList(name) } catch {
                        toast = error.apiMessage(fallback: "No se ha podido crear la lista.")
                    }
                }
            }
        }
        .sheet(isPresented: $reordering) {
            ReorderListsView(lists: (lists ?? []).filter { !$0.isInbox }) { ids in
                Task {
                    do { try await TaskActions(api: api).reorderLists(ids) } catch {
                        toast = error.apiMessage(fallback: "No se ha podido reordenar.")
                    }
                }
            }
        }
        .carliToast($toast)
    }

    private func row(_ list: TaskList, subtitle: String? = nil) -> some View {
        NavigationLink(value: TaskListRoute(id: list.id)) {
            HStack(spacing: CarliSpace.s12) {
                IconBubble(symbol: list.symbol, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(list.name).foregroundStyle(CarliColor.text)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(CarliColor.text2) }
                }
                Spacer()
                Text("\(list.openCount)").monospacedDigit().foregroundStyle(CarliColor.text2)
            }
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[TaskList]> = try await api.get("v1/tasks/lists")
            lists = envelope.data
            failed = nil
        } catch {
            if lists == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }
}

private struct ReorderListsView: View {
    @State var lists: [TaskList]
    var save: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(lists) { Text($0.name) }
                    .onMove { lists.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ordenar listas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar orden", role: .confirm) {
                        save(lists.map(\.id))
                        dismiss()
                    }
                }
            }
        }
    }
}

/// One list: open tasks with a date first, then the undated ones.
struct ListDetailView: View {
    let api: APIClient
    let listId: String

    @Environment(\.dismiss) private var dismiss
    @State private var list: TaskList?
    @State private var tasks: [TaskItem]?
    @State private var failed: String?
    @State private var adding = false
    @State private var renaming = false
    @State private var name = ""
    @State private var handler: TaskListActions

    init(api: APIClient, listId: String) {
        self.api = api
        self.listId = listId
        _handler = State(initialValue: TaskListActions(api: api))
    }

    var body: some View {
        List {
            if let tasks {
                if tasks.isEmpty {
                    ContentUnavailableView {
                        Label("Lista vacía", systemImage: "checklist")
                    } description: {
                        Text("Las tareas abiertas de esta lista aparecerán aquí, con o sin fecha.")
                    } actions: {
                        Button("Nueva tarea") { adding = true }.buttonStyle(.glass)
                    }
                }
                let dated = tasks.filter { $0.dueDate != nil }
                let undated = tasks.filter { $0.dueDate == nil }
                if !dated.isEmpty {
                    Section { ForEach(dated) { row($0, date: .relative) } }
                }
                if !undated.isEmpty {
                    Section("Sin fecha") { ForEach(undated) { row($0, date: .hidden) } }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las tareas", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle(list?.name ?? "Lista")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nueva tarea en esta lista", systemImage: "plus") { adding = true }
            }
            if let list {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Renombrar", systemImage: "pencil") {
                            name = list.name
                            renaming = true
                        }
                        if !list.isInbox {
                            Button("Archivar", systemImage: "archivebox") { Task { await archive(list) } }
                            Button("Borrar (solo si está vacía)", systemImage: "trash", role: .destructive) { Task { await delete(list) } }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Opciones de la lista")
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onTasksChanged { await load() }
        .taskListActions(handler)
        .sheet(isPresented: $adding) { NewTaskSheet(api: api, listId: listId, date: nil) }
        .alert("Renombrar lista", isPresented: $renaming) {
            TextField("Nombre", text: $name)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, let list else { return }
                Task {
                    do { try await handler.actions.updateList(list.id, ["name": .string(trimmed)]) } catch {
                        handler.toast = error.apiMessage(fallback: "No se ha podido guardar la lista.")
                    }
                }
            }
        }
    }

    private func row(_ item: TaskItem, date: TaskRowView.DateStyle) -> some View {
        NavigationLink(value: TaskRoute(id: item.id)) {
            TaskRowView(item: item, date: date, showList: false, toggle: { handler.toggle(item) }, postpone: { handler.postponing = item })
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[TaskItem]> = try await api.get("v1/tasks/tasks", query: ["list_id": listId, "status": "open"])
            tasks = envelope.data
            failed = nil
        } catch {
            if tasks == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
        if let lists: DataEnvelope<[TaskList]> = try? await api.get("v1/tasks/lists") {
            list = lists.data.first { $0.id == listId }
        }
    }

    private func archive(_ list: TaskList) async {
        do {
            try await handler.actions.updateList(list.id, ["archived": .bool(true)])
            dismiss()
        } catch {
            handler.toast = error.apiMessage(fallback: "No se ha podido archivar la lista.")
        }
    }

    private func delete(_ list: TaskList) async {
        do {
            try await handler.actions.deleteList(list.id)
            dismiss()
        } catch {
            handler.toast = error.apiMessage(fallback: "No se ha podido borrar la lista.")
        }
    }
}

/// Completed tasks grouped by the day they were done.
struct DoneTasksView: View {
    let api: APIClient
    @State private var tasks: [TaskItem]?
    @State private var failed: String?
    @State private var handler: TaskListActions

    init(api: APIClient) {
        self.api = api
        _handler = State(initialValue: TaskListActions(api: api))
    }

    var body: some View {
        List {
            if let tasks {
                if tasks.isEmpty {
                    ContentUnavailableView("Aún no has completado nada", systemImage: "checkmark.circle",
                                           description: Text("Lo que marques como hecho quedará registrado aquí."))
                }
                ForEach(groups(tasks), id: \.0) { day, items in
                    Section(CarliDate.dayTitle(day)) {
                        ForEach(items) { item in
                            NavigationLink(value: TaskRoute(id: item.id)) {
                                TaskRowView(item: item, postponable: false, toggle: { handler.toggle(item) }, postpone: {})
                            }
                        }
                    }
                }
            } else if let failed {
                ContentUnavailableView("No se ha podido cargar el registro", systemImage: "exclamationmark.circle",
                                       description: Text(failed))
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Hechas")
        .refreshable { await load() }
        .task { await load() }
        .onTasksChanged { await load() }
        .taskListActions(handler)
    }

    private func groups(_ items: [TaskItem]) -> [(String, [TaskItem])] {
        var order: [String] = []
        var map: [String: [TaskItem]] = [:]
        for item in items {
            let day = item.completedAt.flatMap(CarliDate.instant).map(CarliDate.isoDay) ?? CarliDate.isoDay(.now)
            if map[day] == nil { order.append(day) }
            map[day, default: []].append(item)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[TaskItem]> = try await api.get("v1/tasks/tasks", query: ["status": "done"])
            tasks = envelope.data
        } catch {
            if tasks == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }
}

struct ArchivedListsView: View {
    let api: APIClient
    @State private var lists: [TaskList]?
    @State private var toast: String?

    var body: some View {
        List {
            if let lists {
                if lists.isEmpty {
                    ContentUnavailableView("Nada archivado", systemImage: "archivebox",
                                           description: Text("Las listas que archives quedan aquí y puedes recuperarlas."))
                }
                ForEach(lists) { list in
                    HStack {
                        Label(list.name, systemImage: "archivebox")
                        Spacer()
                        Button("Recuperar") {
                            Task {
                                do { try await TaskActions(api: api).updateList(list.id, ["archived": .bool(false)]) } catch {
                                    toast = error.apiMessage(fallback: "No se ha podido recuperar la lista.")
                                }
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Archivadas")
        .task { await load() }
        .onTasksChanged { await load() }
        .carliToast($toast)
    }

    private func load() async {
        if let envelope: DataEnvelope<[TaskList]> = try? await api.get("v1/tasks/lists", query: ["archived": "1"]) {
            lists = envelope.data
        } else if lists == nil {
            lists = []
        }
    }
}
