import SwiftUI

/// One task: title, date, time, list, important, its template, subtasks, notes and actions.
struct TaskDetailView: View {
    let api: APIClient
    let taskId: String

    @Environment(\.dismiss) private var dismiss
    @State private var item: TaskItem?
    @State private var failed: String?
    @State private var lists: [TaskList] = []
    @State private var title = ""
    @State private var notes = ""
    @State private var subtaskDraft = ""
    @State private var history: TemplateHistory?
    @State private var nextDate: String?
    @State private var choosingDate = false
    @State private var choosingTime = false
    @State private var postponing = false
    @State private var confirmingDelete = false
    @State private var toast: String?
    @State private var undo: UndoOffer?
    @FocusState private var focused: Field?

    private enum Field { case title, notes, subtask }
    private var actions: TaskActions { TaskActions(api: api) }

    var body: some View {
        Form {
            if let item {
                content(item)
            } else if let failed {
                ContentUnavailableView("No se ha podido cargar la tarea", systemImage: "exclamationmark.circle",
                                       description: Text(failed))
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Tarea")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onTasksChanged { await load() }
        .onChange(of: focused) { old, _ in if old == .title || old == .notes { saveText() } }
        .sheet(isPresented: $choosingDate) {
            TaskDatePicker(current: item?.dueDate.flatMap(CarliDate.day)) { date in
                Task { await update(["due_date": .optional(date.map(CarliDate.isoDay))]) }
            }
        }
        .sheet(isPresented: $choosingTime) {
            TaskTimePicker(current: item?.dueTime) { time in
                var fields: [String: JSONValue] = ["due_time": .optional(time)]
                if item?.dueDate == nil, time != nil { fields["due_date"] = .string(CarliDate.isoDay(.now)) }
                Task { await update(fields) }
            }
        }
        .sheet(isPresented: $postponing) {
            if let item {
                PostponeSheet(from: item.dueDate.flatMap(CarliDate.day), includeToday: item.isOverdue) { date in
                    Task {
                        do { try await actions.postpone(item, to: date) } catch {
                            toast = error.apiMessage(fallback: "No se ha podido posponer la tarea.")
                        }
                    }
                }
            }
        }
        .confirmationDialog("Borrar “\(item?.title ?? "")”", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { Task { await delete() } }
        }
        .undoBar($undo, seconds: 4)
        .carliToast($toast)
    }

    @ViewBuilder
    private func content(_ item: TaskItem) -> some View {
        Section {
            HStack(alignment: .top, spacing: 0) {
                TaskCheck(done: item.isDone, size: 28, label: item.isDone ? "Desmarcar" : "Marcar como hecha") { toggle(item) }
                    .padding(.leading, -8)
                TextField("Título", text: $title, axis: .vertical)
                    .font(.title2.weight(.semibold))
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? CarliColor.text2 : CarliColor.text)
                    .focused($focused, equals: .title)
                    .submitLabel(.done)
                    .onSubmit(saveText)
                    .padding(.top, 6)
            }
            if item.status == "skipped" {
                Text("Omitida").font(.footnote.weight(.semibold)).foregroundStyle(CarliColor.text2)
            }
        }

        Section {
            Button { choosingDate = true } label: {
                LabeledContent("Fecha", value: item.dueDate.flatMap(CarliDate.day).map { "\(TaskDates.dueLabel($0)), \(TaskDates.weekdayShort($0))" } ?? "Sin fecha")
            }
            Button { choosingTime = true } label: { LabeledContent("Hora", value: item.dueTime ?? "Sin hora") }
            Picker("Lista", selection: Binding(get: { item.list?.id ?? "" }, set: { id in
                guard id != item.list?.id else { return }
                Task { await update(["list_id": .string(id)]) }
            })) {
                ForEach(lists) { Text($0.name).tag($0.id) }
                if lists.isEmpty, let list = item.list { Text(list.name).tag(list.id) }
            }
            Toggle("Importante", isOn: Binding(get: { item.isImportant }, set: { value in
                Task { await update(["important": .bool(value)]) }
            }))
        }
        .foregroundStyle(CarliColor.text)

        if let template = item.template {
            Section {
                NavigationLink(value: TemplateRoute(id: template.id)) {
                    HStack(spacing: CarliSpace.s12) {
                        IconBubble(symbol: "repeat", size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(template.frequencyText ?? "Se repite").fontWeight(.semibold)
                            let parts = [history?.streakLabel, nextDate.flatMap(CarliDate.day).map { "siguiente \(TaskDates.weekdayShort($0))" },
                                         template.paused == true ? "pausada" : nil].compactMap { $0 }
                            if !parts.isEmpty {
                                Text(parts.joined(separator: " · ")).font(.footnote).foregroundStyle(CarliColor.text2)
                            }
                        }
                    }
                }
            }
        }

        Section(item.steps.isEmpty ? "Subtareas" : "Subtareas · \(item.stepsDone) de \(item.steps.count)") {
            ForEach(item.steps) { subtask in
                HStack(spacing: 0) {
                    TaskCheck(done: subtask.done, size: 20, label: subtask.done ? "Desmarcar \(subtask.title)" : "Marcar \(subtask.title)") {
                        Task {
                            do { try await actions.setSubtask(item, subtask, done: !subtask.done) } catch {
                                toast = error.apiMessage(fallback: "No se ha podido guardar la subtarea.")
                            }
                        }
                    }
                    .padding(.leading, -10)
                    Text(subtask.title)
                        .strikethrough(subtask.done)
                        .foregroundStyle(subtask.done ? CarliColor.text2 : CarliColor.text)
                }
                .swipeActions {
                    Button("Borrar", systemImage: "trash", role: .destructive) {
                        Task {
                            do { try await actions.deleteSubtask(item, subtask) } catch {
                                toast = error.apiMessage(fallback: "No se ha podido borrar la subtarea.")
                            }
                        }
                    }
                    .tint(CarliColor.dangerFill)
                }
            }
            TextField("Añadir subtarea", text: $subtaskDraft)
                .focused($focused, equals: .subtask)
                .submitLabel(.done)
                .onSubmit { addSubtask(item) }
        }

        Section {
            TextField("Notas", text: $notes, axis: .vertical)
                .lineLimit(2...10)
                .focused($focused, equals: .notes)
        }

        if item.isOpen {
            Section {
                Button("Posponer", systemImage: "calendar") { postponing = true }
                Button(item.template == nil ? "Omitir" : "Saltar esta vez", systemImage: "forward") { Task { await skip(item) } }
            }
        }
        Section {
            Button("Borrar tarea", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<TaskItem> = try await api.get("v1/tasks/tasks/\(taskId)")
            let fresh = envelope.data
            if focused != .title { title = fresh.title }
            if focused != .notes { notes = fresh.notes ?? "" }
            item = fresh
            if let template = fresh.template {
                if let entry: DataEnvelope<TemplateHistory> = try? await api.get("v1/tasks/templates/\(template.id)/history") {
                    history = entry.data
                }
                if let full: DataEnvelope<TaskTemplate> = try? await api.get("v1/tasks/templates/\(template.id)") {
                    nextDate = full.data.upcomingDates?.first
                }
            }
        } catch {
            if item == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
        if lists.isEmpty, let all: DataEnvelope<[TaskList]> = try? await api.get("v1/tasks/lists") { lists = all.data }
    }

    private func update(_ fields: [String: JSONValue]) async {
        do { try await actions.update(taskId, fields) } catch {
            toast = error.apiMessage(fallback: "No se ha podido guardar la tarea.")
        }
    }

    private func saveText() {
        guard let item else { return }
        var fields: [String: JSONValue] = [:]
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty, trimmedTitle != item.title { fields["title"] = .string(trimmedTitle) }
        if trimmedNotes != (item.notes ?? "") { fields["notes"] = trimmedNotes.isEmpty ? .null : .string(trimmedNotes) }
        if !fields.isEmpty { Task { await update(fields) } }
    }

    private func toggle(_ item: TaskItem) {
        Task {
            do {
                if item.isDone {
                    try await actions.reopen(item)
                } else {
                    try await actions.complete(item)
                    undo = UndoOffer(text: "\(item.title) hecha") { [actions] in try? await actions.reopen(item) }
                }
            } catch {
                toast = error.apiMessage(fallback: "No se ha podido completar la tarea.")
            }
        }
    }

    private func addSubtask(_ item: TaskItem) {
        let text = subtaskDraft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        subtaskDraft = ""
        Task {
            do { try await actions.addSubtask(item, title: text) } catch {
                toast = error.apiMessage(fallback: "No se ha podido añadir la subtarea.")
            }
        }
        focused = .subtask
    }

    private func skip(_ item: TaskItem) async {
        do {
            try await actions.skip(item)
            dismiss()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido omitir la tarea.")
        }
    }

    private func delete() async {
        guard let item else { return }
        do {
            try await actions.delete(item)
            dismiss()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar la tarea.")
        }
    }
}

/// Quick dates plus a calendar; `nil` clears the date.
struct TaskDatePicker: View {
    var current: Date?
    var pick: (Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            List {
                ForEach(QuickDate.allCases) { option in
                    Button {
                        pick(option.resolve())
                        dismiss()
                    } label: {
                        LabeledContent(option.label, value: option.resolve().map(TaskDates.weekdayShort) ?? "")
                    }
                    .foregroundStyle(CarliColor.text)
                }
                Section {
                    DatePicker("Elegir fecha", selection: $date, displayedComponents: .date).datePickerStyle(.graphical)
                    Button("Usar \(TaskDates.weekdayShort(date))") {
                        pick(date)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { date = current ?? .now }
    }
}

/// 24 h wheel in 5-minute steps; "Quitar hora" clears it.
struct TaskTimePicker: View {
    var current: String?
    var pick: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var time = Date.now

    var body: some View {
        NavigationStack {
            VStack(spacing: CarliSpace.s16) {
                DatePicker("Hora", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "es_ES"))
                if current != nil {
                    Button("Quitar hora", role: .destructive) {
                        pick(nil)
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding()
            .navigationTitle("Hora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", role: .confirm) {
                        pick(TaskDates.time(time))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
        .onAppear {
            let base = TaskDates.date(fromTime: current)
            let minute = CarliDate.calendar.component(.minute, from: base)
            time = CarliDate.calendar.date(byAdding: .minute, value: -(minute % 5), to: base) ?? base
        }
    }
}
