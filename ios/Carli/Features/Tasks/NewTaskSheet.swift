import SwiftUI

/// "+" in Tareas: title, notes, when, list, time, repeat and important.
struct NewTaskSheet: View {
    let api: APIClient
    var listId: String?
    var date: Date?
    var onSaved: ((String) -> Void)?
    var openTemplate: ((TemplateSeed) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var when: Date?
    @State private var list: String?
    @State private var time: String?
    @State private var important = false
    @State private var lists: [TaskList] = []
    @State private var defaultListId: String?
    @State private var saving = false
    @State private var error: String?
    @State private var choosingDate = false
    @State private var choosingTime = false
    @FocusState private var titleFocused: Bool

    init(api: APIClient, listId: String? = nil, date: Date? = .now, onSaved: ((String) -> Void)? = nil,
         openTemplate: ((TemplateSeed) -> Void)? = nil) {
        self.api = api
        self.listId = listId
        self.date = date
        self.onSaved = onSaved
        self.openTemplate = openTemplate
        _when = State(initialValue: date.map { CarliDate.calendar.startOfDay(for: $0) })
        _list = State(initialValue: listId)
    }

    private var effectiveList: String? { list ?? defaultListId ?? lists.first(where: \.isInbox)?.id }
    private var listName: String { lists.first { $0.id == effectiveList }?.name ?? "Bandeja" }
    private var canSave: Bool { !saving && !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("¿Qué hay que hacer?", text: $title, axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await save() } }
                    TextField("Notas", text: $notes, axis: .vertical)
                }
                Section("Cuándo") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CarliSpace.s8) {
                            let quick = QuickDate.of(when)
                            let chips: [QuickDate] = [.today, .tomorrow, .weekend, .none]
                            let custom = quick == nil || !chips.contains(quick!)
                            ForEach(chips) { option in
                                Chip(label: option.label, selected: !custom && quick == option) {
                                    when = option.resolve()
                                    if when == nil { time = nil }
                                }
                            }
                            Chip(label: custom && when != nil ? TaskDates.weekdayShort(when!) : "Elegir…", symbol: "calendar",
                                 selected: custom && when != nil) { choosingDate = true }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: CarliSpace.s8, leading: CarliSpace.s16, bottom: CarliSpace.s8, trailing: CarliSpace.s16))
                }
                Section {
                    Picker(selection: Binding(get: { effectiveList ?? "" }, set: { list = $0 })) {
                        ForEach(lists) { Label($0.name, systemImage: $0.symbol).tag($0.id) }
                    } label: {
                        Label("Lista", systemImage: "list.bullet")
                    }
                    Button { choosingTime = true } label: {
                        LabeledContent { Text(time ?? "Sin hora") } label: { Label("Hora", systemImage: "clock") }
                    }
                    .foregroundStyle(CarliColor.text)
                    Toggle(isOn: $important) { Label("Importante", systemImage: "flag") }
                    if let openTemplate {
                        Button {
                            let seed = TemplateSeed(title: title.trimmingCharacters(in: .whitespaces), notes: notes, listId: effectiveList,
                                                    dueTime: time, important: important, start: when)
                            dismiss()
                            openTemplate(seed)
                        } label: {
                            Label("Repetir…", systemImage: "repeat")
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle("Nueva tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Añadir", role: .confirm) { Task { await save() } }.disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $choosingDate) {
                TaskDatePicker(current: when) { when = $0; if $0 == nil { time = nil } }
            }
            .sheet(isPresented: $choosingTime) {
                TaskTimePicker(current: time) { picked in
                    time = picked
                    if picked != nil, when == nil { when = CarliDate.calendar.startOfDay(for: .now) }
                }
            }
            .task {
                titleFocused = true
                if let all: DataEnvelope<[TaskList]> = try? await api.get("v1/tasks/lists") { lists = all.data }
                defaultListId = await ModuleSettings.load(api, module: AppModule.tasks, as: TasksSettings.self)?.defaultListId
            }
        }
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        error = nil
        defer { saving = false }
        var fields: [String: JSONValue] = [
            "title": .string(title.trimmingCharacters(in: .whitespaces)),
            "due_date": .optional(when.map(CarliDate.isoDay)),
            "important": .bool(important),
        ]
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty { fields["notes"] = .string(trimmedNotes) }
        if let list { fields["list_id"] = .string(list) }
        if when != nil { fields["due_time"] = .optional(time) }
        do {
            try await TaskActions(api: api).create(fields)
            onSaved?("Tarea añadida")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido crear la tarea.")
        }
    }
}

/// Capsule toggle chip.
struct Chip: View {
    var label: String
    var symbol: String?
    var selected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(label)
            } icon: {
                if let symbol { Image(systemName: symbol) }
            }
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, CarliSpace.s12)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? CarliColor.onPrimary : CarliColor.text)
            .background(selected ? CarliColor.primary : CarliColor.surface2, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
