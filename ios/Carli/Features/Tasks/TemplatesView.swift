import SwiftUI

/// Tareas › Plantillas: what repeats, active first, paused after.
struct TemplatesView: View {
    let api: APIClient

    @State private var templates: [TaskTemplate]?
    @State private var failed: String?

    var body: some View {
        List {
            if let templates {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("Sin plantillas", systemImage: "repeat")
                    } description: {
                        Text("Crea una para lo que se repite: sacar la basura, regar las plantas o pagar la comunidad.")
                    } actions: {
                        NavigationLink("Nueva plantilla", value: TemplateRoute(id: nil)).buttonStyle(.glass)
                    }
                } else {
                    let active = templates.filter { !$0.isPaused }
                    let paused = templates.filter(\.isPaused)
                    Text([active.count == 1 ? "1 activa" : "\(active.count) activas",
                          paused.isEmpty ? nil : paused.count == 1 ? "1 pausada" : "\(paused.count) pausadas"]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                        .listRowBackground(Color.clear)
                    if !active.isEmpty { Section { ForEach(active) { row($0) } } }
                    if !paused.isEmpty { Section("Pausadas") { ForEach(paused) { row($0) } } }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las plantillas", systemImage: "exclamationmark.circle")
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
                NavigationLink(value: TemplateRoute(id: nil)) { Image(systemName: "repeat.circle") }
                    .accessibilityLabel("Nueva plantilla")
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onTasksChanged { await load() }
        .tasksDestinations(api: api)
    }

    private func row(_ template: TaskTemplate) -> some View {
        NavigationLink(value: TemplateRoute(id: template.id)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title).foregroundStyle(CarliColor.text)
                    Text(template.rule).font(.footnote).foregroundStyle(CarliColor.text2).lineLimit(2)
                }
                Spacer()
                if template.isPaused {
                    CarliBadge(label: "Pausada", symbol: "clock")
                } else {
                    Text(template.nextDate.flatMap(CarliDate.day).map { "\(template.afterDone ? "≈ " : "")\(TaskDates.weekdayShort($0))" } ?? "—")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
            }
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[TaskTemplate]> = try await api.get("v1/tasks/templates")
            templates = envelope.data
            failed = nil
        } catch {
            if templates == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }
}

/// New / edit template: frequency, live preview, policy, subtasks, lead days, ending, history.
struct TemplateEditorView: View {
    enum Ending: String, CaseIterable, Identifiable {
        case never, until, count
        var id: String { rawValue }
        var label: String {
            switch self {
            case .never: "Nunca"
            case .until: "En una fecha"
            case .count: "Tras un número de veces"
            }
        }
    }

    let api: APIClient
    let templateId: String?
    let seed: TemplateSeed

    @Environment(\.dismiss) private var dismiss
    @State private var template: TaskTemplate?
    @State private var loaded = false
    @State private var title = ""
    @State private var notes = ""
    @State private var subtasks: [String] = []
    @State private var subtaskDraft = ""
    @State private var frequency = FrequencyDraft()
    @State private var start = Date.now
    @State private var ending: Ending = .never
    @State private var until = Date.now
    @State private var count = 10
    @State private var policy: TemplatePolicy = .replace
    @State private var leadDays = 0
    @State private var time: String?
    @State private var listId: String?
    @State private var important = false
    @State private var lists: [TaskList] = []
    @State private var preview: FrequencyPreview?
    @State private var previewError: String?
    @State private var history: TemplateHistory?
    @State private var habitsOn = false
    @State private var saving = false
    @State private var askApply = false
    @State private var confirmingDelete = false
    @State private var askDeleteOpen = false
    @State private var choosingTime = false
    @State private var converting = false
    @State private var toast: String?

    private var actions: TaskActions { TaskActions(api: api) }

    var body: some View {
        Form {
            if templateId != nil && !loaded {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                editor
            }
        }
        .navigationTitle("Plantilla")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if saving { ProgressView() } else {
                    Button("Guardar") {
                        if template?.openTaskId != nil { askApply = true } else { Task { await save(applyToOpen: false) } }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .task { await load() }
        .task(id: previewKey) {
            try? await Task.sleep(for: .milliseconds(300))
            await refreshPreview()
        }
        .sheet(isPresented: $choosingTime) {
            TaskTimePicker(current: time) { time = $0 }
        }
        .sheet(isPresented: $converting) {
            if let template { ConvertTemplateSheet(api: api, templateId: template.id) { toast = $0 } }
        }
        .confirmationDialog("¿Aplicar también a la tarea abierta?", isPresented: $askApply, titleVisibility: .visible) {
            Button("Aplicar también") { Task { await save(applyToOpen: true) } }
            Button("Solo a las próximas") { Task { await save(applyToOpen: false) } }
        } message: {
            Text("Los cambios se aplican a las próximas. La tarea que ya está abierta puede quedarse como está.")
        }
        .confirmationDialog("Borrar “\(template?.title ?? "")”", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if template?.openTaskId != nil { askDeleteOpen = true } else { Task { await delete(deleteOpen: false) } }
            }
        } message: {
            Text("Las tareas que ya se generaron se quedan. No se crearán más.")
        }
        .confirmationDialog("¿Borrar también la tarea abierta?", isPresented: $askDeleteOpen, titleVisibility: .visible) {
            Button("Borrar también", role: .destructive) { Task { await delete(deleteOpen: true) } }
            Button("Dejarla") { Task { await delete(deleteOpen: false) } }
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private var editor: some View {
        Section {
            TextField("Título", text: $title)
                .font(.headline)
            Picker("Lista", selection: Binding(get: { listId ?? lists.first(where: \.isInbox)?.id ?? "" }, set: { listId = $0 })) {
                ForEach(lists) { Text($0.name).tag($0.id) }
            }
            TextField("Notas", text: $notes, axis: .vertical)
        }

        Section {
            Picker("Tipo", selection: $frequency.afterDone) {
                Text("En fechas fijas").tag(false)
                Text("Tras completarla").tag(true)
            }
            .pickerStyle(.segmented)
            if frequency.afterDone {
                Stepper("\(frequency.afterDoneDays) días después de hacerla", value: $frequency.afterDoneDays, in: 1...3650)
            } else {
                scheduleEditor
            }
            Button { choosingTime = true } label: { LabeledContent("Hora", value: time ?? "Sin hora") }
                .foregroundStyle(CarliColor.text)
        } header: {
            Text("Frecuencia")
        } footer: {
            Text(previewError ?? summary)
                .foregroundStyle(previewError == nil ? CarliColor.text : CarliColor.negative)
        }

        Section(frequency.afterDone ? "Si la haces hoy" : "Próximas fechas") {
            if let preview {
                if preview.dates.isEmpty {
                    Text("Sin fechas próximas").foregroundStyle(CarliColor.text2)
                }
                ForEach(preview.dates, id: \.self) { iso in
                    if let date = CarliDate.day(iso) {
                        LabeledContent(TaskDates.weekdayShort(date), value: TaskDates.distance(date))
                    }
                }
            } else {
                ProgressView()
            }
        }

        Section("Si no la completas") {
            if frequency.afterDone {
                Text("Con “Tras completarla” nunca hay dos abiertas: la siguiente se calcula al hacerla u omitirla.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
            } else {
                Picker("Política", selection: $policy) {
                    ForEach(TemplatePolicy.allCases) { option in
                        VStack(alignment: .leading) {
                            Text(option.label)
                            Text(option.hint).font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                        .tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }

        Section("Subtareas") {
            ForEach(Array(subtasks.enumerated()), id: \.offset) { index, subtask in
                Text(subtask)
                    .swipeActions {
                        DeleteSwipeButton("Quitar", systemImage: "xmark") { subtasks.remove(at: index) }
                    }
            }
            .onMove { subtasks.move(fromOffsets: $0, toOffset: $1) }
            TextField("Añadir subtarea", text: $subtaskDraft)
                .submitLabel(.done)
                .onSubmit {
                    let text = subtaskDraft.trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty { subtasks.append(text) }
                    subtaskDraft = ""
                }
        }

        Section {
            Picker("Aparece", selection: $leadDays) {
                ForEach([0, 1, 2, 3, 7, 14, 30], id: \.self) { days in
                    Text(days == 0 ? "El mismo día" : days == 1 ? "1 día antes" : "\(days) días antes").tag(days)
                }
            }
            DatePicker("Empieza", selection: $start, displayedComponents: .date)
            Picker("Termina", selection: $ending) {
                ForEach(Ending.allCases) { Text($0.label).tag($0) }
            }
            if ending == .until {
                DatePicker("Hasta", selection: $until, in: start..., displayedComponents: .date)
            }
            if ending == .count {
                Stepper("\(count == 1 ? "1 vez" : "\(count) veces")", value: $count, in: 1...10000)
            }
            Toggle("Importante", isOn: $important)
        }

        if let template {
            Section(history?.streakLabel ?? "Historial") {
                if let history {
                    if history.items.isEmpty {
                        Text("Aún sin historial").foregroundStyle(CarliColor.text2)
                    }
                    ForEach(history.items.prefix(10)) { entry in
                        HStack {
                            Text(CarliDate.day(entry.date).map(TaskDates.weekdayShort) ?? entry.date)
                            Spacer()
                            Text(entry.label).foregroundStyle(CarliColor.text2)
                            Circle().fill(entry.status == "done" ? CarliColor.positive : CarliColor.text3.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            Section {
                if habitsOn && HabitConversion.canConvert(rrule: template.rrule) {
                    Button("Convertir en hábito", systemImage: "repeat") { converting = true }
                }
                Button(template.isPaused ? "Reanudar plantilla" : "Pausar plantilla",
                       systemImage: template.isPaused ? "play" : "pause") { Task { await togglePaused(template) } }
                Button("Borrar plantilla", systemImage: "trash", role: .destructive) { confirmingDelete = true }
            }
        }
    }

    @ViewBuilder
    private var scheduleEditor: some View {
        Picker("Repetición", selection: $frequency.unit) {
            ForEach(FrequencyDraft.Unit.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        Stepper(frequency.intervalLabel, value: $frequency.interval, in: 1...99)
        switch frequency.unit {
        case .daily:
            EmptyView()
        case .weekly:
            WeekdayToggles(selected: frequency.weekdays) { frequency.toggle($0) }
        case .monthly:
            Picker("Modo", selection: $frequency.monthlyMode) {
                ForEach(FrequencyDraft.MonthlyMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            switch frequency.monthlyMode {
            case .dayOfMonth:
                Stepper("El día \(frequency.monthDay)", value: $frequency.monthDay, in: 1...31)
            case .lastDay:
                EmptyView()
            case .weekdayPosition:
                Picker("Posición", selection: $frequency.position) {
                    ForEach(FrequencyDraft.positions, id: \.0) { Text($0.1).tag($0.0) }
                }
                WeekdayToggles(selected: [frequency.positionWeekday]) { frequency.positionWeekday = $0 }
            }
        case .yearly:
            Picker("Mes", selection: $frequency.yearMonth) {
                ForEach(1...12, id: \.self) { Text(CarliDate.months[$0 - 1].capitalizedFirst).tag($0) }
            }
            Stepper("El día \(frequency.monthDay)", value: $frequency.monthDay, in: 1...31)
        }
    }

    private var summary: String {
        var parts = [preview?.description ?? ""]
        if let time { parts.append("a las \(time)") }
        return parts.filter { !$0.isEmpty }.joined(separator: " ").capitalizedFirst
    }

    private var frequencyFields: [String: JSONValue] {
        var fields = frequency.fields
        fields["dtstart"] = .string(CarliDate.isoDay(start))
        fields["until"] = ending == .until ? .string(CarliDate.isoDay(until)) : .null
        fields["count"] = ending == .count ? .int(count) : .null
        return fields
    }

    private var previewKey: String {
        "\(frequency.rrule ?? "")|\(frequency.afterDone)|\(frequency.afterDoneDays)|\(CarliDate.isoDay(start))|\(ending)|\(CarliDate.isoDay(until))|\(count)"
    }

    private func load() async {
        if let all: DataEnvelope<[TaskList]> = try? await api.get("v1/tasks/lists") { lists = all.data }
        habitsOn = await HabitConversion.habitsEnabled(api)
        guard !loaded else { return }
        let settings = await ModuleSettings.load(api, module: AppModule.tasks, as: TasksSettings.self)
        if let templateId {
            guard let envelope: DataEnvelope<TaskTemplate> = try? await api.get("v1/tasks/templates/\(templateId)") else {
                toast = "No se ha podido cargar la plantilla."
                return
            }
            let template = envelope.data
            self.template = template
            title = template.title
            notes = template.notes ?? ""
            subtasks = template.subtasks ?? []
            start = CarliDate.day(template.dtstart) ?? .now
            frequency = .parse(rrule: template.rrule, afterDoneDays: template.afterDoneIntervalDays, start: start)
            if let date = template.until.flatMap(CarliDate.day) {
                ending = .until
                until = date
            } else if let total = template.count {
                ending = .count
                count = total
            }
            policy = TemplatePolicy(rawValue: template.policy ?? "") ?? .replace
            leadDays = template.leadDays ?? 0
            time = template.dueTime
            listId = template.list.id
            important = template.important == true
            if let entry: DataEnvelope<TemplateHistory> = try? await api.get("v1/tasks/templates/\(templateId)/history") {
                history = entry.data
            }
        } else {
            title = seed.title
            notes = seed.notes
            start = seed.start ?? .now
            frequency = .initial(start)
            policy = settings?.policy ?? .replace
            time = seed.dueTime
            listId = seed.listId
            important = seed.important
            until = CarliDate.calendar.date(byAdding: .day, value: 30, to: start) ?? start
        }
        loaded = true
    }

    private func refreshPreview() async {
        var body: [String: JSONValue] = [:]
        for (key, value) in frequencyFields where value != .null { body[key] = value }
        do {
            let result: DataEnvelope<FrequencyPreview> = try await api.post("v1/tasks/templates/preview", body: Patch(body))
            preview = result.data
            previewError = nil
        } catch {
            previewError = "No se ha podido calcular la frecuencia."
        }
    }

    private func save(applyToOpen: Bool) async {
        saving = true
        defer { saving = false }
        var fields = frequencyFields
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        fields["title"] = .string(title.trimmingCharacters(in: .whitespaces))
        fields["notes"] = trimmedNotes.isEmpty ? .null : .string(trimmedNotes)
        if let listId { fields["list_id"] = .string(listId) }
        fields["subtasks"] = .array(subtasks.map(JSONValue.string))
        fields["due_time"] = .optional(time)
        fields["important"] = .bool(important)
        fields["policy"] = .string(policy.rawValue)
        fields["lead_days"] = .int(leadDays)
        do {
            if let template {
                fields["apply_to_open"] = .bool(applyToOpen)
                let _: Empty = try await api.patch("v1/tasks/templates/\(template.id)", body: Patch(fields))
            } else {
                let _: Empty = try await api.post("v1/tasks/templates", body: Patch(fields))
            }
            NotificationCenter.default.post(name: .tasksChanged, object: nil)
            dismiss()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido guardar la plantilla.")
        }
    }

    private func togglePaused(_ template: TaskTemplate) async {
        do {
            let updated: DataEnvelope<TaskTemplate> = try await api.post("v1/tasks/templates/\(template.id)/\(template.isPaused ? "resume" : "pause")")
            self.template = updated.data
            NotificationCenter.default.post(name: .tasksChanged, object: nil)
            toast = updated.data.isPaused ? "Plantilla pausada" : "Plantilla reanudada"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido actualizar la plantilla.")
        }
    }

    private func delete(deleteOpen: Bool) async {
        guard let template else { return }
        do {
            let _: Empty = try await api.request("DELETE", "v1/tasks/templates/\(template.id)",
                                                 query: deleteOpen ? ["delete_open": "1"] : [:], body: Optional<Empty>.none)
            NotificationCenter.default.post(name: .tasksChanged, object: nil)
            dismiss()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar la plantilla.")
        }
    }
}

/// L M X J V S D round toggles.
struct WeekdayToggles: View {
    var selected: Set<Int>
    var toggle: (Int) -> Void

    var body: some View {
        HStack {
            ForEach(1...7, id: \.self) { day in
                let on = selected.contains(day)
                Button { toggle(day) } label: {
                    Text(TaskDates.weekdaysMondayFirst[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(on ? CarliColor.onPrimary : CarliColor.text)
                        .background(on ? CarliColor.primary : .clear, in: .circle)
                        .overlay(Circle().strokeBorder(on ? .clear : CarliColor.text3.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(TaskDates.weekdaysLongMondayFirst[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Ajustes de Tareas: default list, default policy, show done in Hoy.
struct TasksSettingsView: View {
    let api: APIClient

    @State private var settings: TasksSettings?
    @State private var lists: [TaskList] = []
    @State private var toast: String?

    var body: some View {
        Form {
            Section {
                Picker("Lista por defecto", selection: Binding(
                    get: { settings?.defaultListId ?? lists.first(where: \.isInbox)?.id ?? "" },
                    set: { id in save(["default_list_id": .string(id)]) { $0.defaultListId = id } })) {
                    ForEach(lists) { Text($0.name).tag($0.id) }
                }
                Picker("Si no la completas", selection: Binding(
                    get: { settings?.policy ?? .replace },
                    set: { policy in save(["default_policy": .string(policy.rawValue)]) { $0.defaultPolicy = policy.rawValue } })) {
                    ForEach(TemplatePolicy.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Mostrar hechas en Hoy", isOn: Binding(
                    get: { settings?.showsDone ?? true },
                    set: { value in save(["show_done_in_today": .bool(value)]) { $0.showDoneInToday = value } }))
                LabeledContent("Avisos a la hora de la tarea", value: "Próximamente")
            } footer: {
                Text("Las tareas vencidas aparecen en Pendientes y las de hoy entran en el resumen de las 20:00.")
            }
        }
        .navigationTitle("Ajustes de Tareas")
        .task {
            settings = await ModuleSettings.load(api, module: AppModule.tasks, as: TasksSettings.self) ?? TasksSettings()
            if let all: DataEnvelope<[TaskList]> = try? await api.get("v1/tasks/lists") { lists = all.data }
        }
        .carliToast($toast)
    }

    private func save(_ fields: [String: JSONValue], apply: (inout TasksSettings) -> Void) {
        let previous = settings
        var next = settings ?? TasksSettings()
        apply(&next)
        settings = next
        Task {
            do {
                try await ModuleSettings.save(api, module: AppModule.tasks, fields)
                NotificationCenter.default.post(name: .tasksChanged, object: nil)
            } catch {
                settings = previous
                toast = error.apiMessage(fallback: "No se han podido guardar los ajustes.")
            }
        }
    }
}
