import SwiftUI

/// What the objective selector offers; each mode maps to a period and, for yes/no, an optional day list.
enum GoalMode: String, CaseIterable, Identifiable {
    case everyDay, someDays, timesPerWeek, perDay, perWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyDay: "Cada día"
        case .someDays: "Días concretos"
        case .timesPerWeek: "Veces por semana"
        case .perDay: "Al día"
        case .perWeek: "A la semana"
        }
    }

    var weekly: Bool { self == .timesPerWeek || self == .perWeek }

    static func forKind(_ kind: HabitKind) -> [GoalMode] {
        kind == .check ? [.everyDay, .someDays, .timesPerWeek] : [.perDay, .perWeek]
    }

    static func of(_ habit: Habit) -> GoalMode {
        switch (habit.kind, habit.goal.weekly) {
        case (.check, true): .timesPerWeek
        case (.check, false): habit.goal.daysOfWeek != nil ? .someDays : .everyDay
        case (_, true): .perWeek
        default: .perDay
        }
    }
}

struct HabitEditorView: View {
    let api: APIClient
    var habit: Habit?
    var onCreated: (String) -> Void = { _ in }

    static let icons = ["check", "book-open", "droplet", "dumbbell", "running", "bike", "heart-pulse", "leaf",
                        "moon", "sun", "bed", "apple", "utensils", "pill", "coffee", "cigarette",
                        "beer", "wine", "smartphone", "tv", "music", "pencil", "graduation-cap", "globe",
                        "phone", "users", "wallet", "target", "flame", "sparkles", "paw-print", "mountain"]

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var unit: String
    @State private var amount: String
    @State private var icon: String
    @State private var kind: HabitKind
    @State private var mode: GoalMode
    @State private var days: Set<Int>
    @State private var times: Int
    @State private var start: Date
    @State private var time: String?
    @State private var showInTasks: Bool
    @State private var saving = false
    @State private var error: String?
    @State private var choosingTime = false

    init(api: APIClient, habit: Habit? = nil, onCreated: @escaping (String) -> Void = { _ in }) {
        self.api = api
        self.habit = habit
        self.onCreated = onCreated
        _name = State(initialValue: habit?.name ?? "")
        _unit = State(initialValue: habit?.unit ?? "")
        _amount = State(initialValue: habit == nil || habit?.kind == .check ? "" : HabitFormat.number(habit!.goal.target))
        _icon = State(initialValue: habit?.icon ?? "check")
        _kind = State(initialValue: habit?.kind ?? .check)
        _mode = State(initialValue: habit.map(GoalMode.of) ?? .everyDay)
        _days = State(initialValue: Set(habit?.goal.daysOfWeek ?? []))
        _times = State(initialValue: habit?.goal.weekly == true && habit?.kind == .check ? Int(habit!.goal.target.rounded()) : 3)
        _start = State(initialValue: habit?.start ?? .now)
        _time = State(initialValue: habit?.preferredTime)
        _showInTasks = State(initialValue: habit?.showInTasks ?? true)
    }

    private var editing: Bool { habit != nil }

    private var target: Double? {
        switch kind {
        case .check: return mode == .timesPerWeek ? Double(times) : 1
        default: return Double(amount.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
            ?? (kind == .avoid ? 0 : nil)
        }
    }

    private var summary: String {
        let unit = unit.trimmingCharacters(in: .whitespaces)
        switch (kind, mode) {
        case (.check, .everyDay): return "Cada día"
        case (.check, .someDays):
            return days.isEmpty ? "Elige los días" : days.sorted().map { TaskDates.weekdaysLongMondayFirst[$0 - 1] }
                .joined(separator: ", ").capitalizedFirst
        case (.check, _): return times == 1 ? "1 vez por semana, cualquier día" : "\(times) veces por semana, cualquier día"
        default: break
        }
        guard let target else { return "Indica la cantidad" }
        if kind == .quantity { return "\(HabitFormat.amount(target, unit)) \(mode.weekly ? "a la semana" : "al día")" }
        if target <= 0 { return mode.weekly ? "Nada en toda la semana" : "Nada" }
        return "Máximo \(HabitFormat.amount(target, unit)) \(mode.weekly ? "por semana" : "al día")"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(CarliColor.negative) }
                }
                Section("Nombre") {
                    TextField("Meditar, beber agua, no fumar…", text: $name)
                }
                Section("Icono") {
                    IconGrid(icons: Self.icons, selection: $icon)
                }
                Section {
                    if editing {
                        LabeledContent("Tipo", value: "\(kind.label) · no se puede cambiar")
                    } else {
                        Picker("Tipo", selection: Binding(get: { kind }, set: setKind)) {
                            ForEach(HabitKind.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if kind != .check {
                        LabeledContent(kind == .avoid ? "Máximo" : "Cantidad") {
                            TextField(kind == .avoid ? "0" : "8", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Unidad") {
                            TextField(kind == .avoid ? "cafés" : "vasos", text: $unit)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("Tipo")
                } footer: {
                    if kind == .avoid {
                        Text("Registras las recaídas o lo que tomas. Un día sin registro cuenta como cumplido.")
                    }
                }
                Section {
                    Picker("Objetivo", selection: $mode) {
                        ForEach(GoalMode.forKind(kind)) { Text($0.label).tag($0) }
                    }
                    if mode == .someDays {
                        HStack {
                            ForEach(1...7, id: \.self) { day in
                                let on = days.contains(day)
                                Button {
                                    if on { days.remove(day) } else { days.insert(day) }
                                } label: {
                                    Text(TaskDates.weekdaysMondayFirst[day - 1])
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(on ? CarliColor.onPrimary : CarliColor.text)
                                        .background(on ? CarliColor.primary : CarliColor.surface2, in: .circle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(TaskDates.weekdaysLongMondayFirst[day - 1])
                                .accessibilityAddTraits(on ? .isSelected : [])
                                if day < 7 { Spacer(minLength: 0) }
                            }
                        }
                    }
                    if mode == .timesPerWeek {
                        Stepper("Veces por semana: \(times)", value: $times, in: 1...7)
                    }
                    Text(summary).fontWeight(.semibold)
                } header: {
                    Text("Objetivo")
                } footer: {
                    if editing {
                        Text("Si cambias el objetivo, se aplica desde hoy. Los días pasados se evalúan con el que tenían.")
                    }
                }
                Section {
                    DatePicker("Empieza", selection: $start, displayedComponents: .date)
                    Button { choosingTime = true } label: {
                        LabeledContent("Momento del día", value: time ?? "Sin hora")
                    }
                    .foregroundStyle(CarliColor.text)
                    if kind != .avoid {
                        Toggle("Mostrar en Hoy de Tareas", isOn: $showInTasks)
                    }
                } footer: {
                    Text("El momento del día solo ordena la lista; en esta versión no hay avisos por hábito.")
                }
            }
            .navigationTitle(editing ? "Editar hábito" : "Nuevo hábito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button(editing ? "Guardar" : "Añadir", systemImage: "checkmark") { Task { await save() } }
                            .buttonStyle(.glassProminent)
                            .tint(CarliColor.primary)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $choosingTime) {
                TaskTimePicker(current: time) { time = $0 }
            }
        }
    }

    private func setKind(_ next: HabitKind) {
        kind = next
        mode = GoalMode.forKind(next)[0]
        if next == .avoid && amount.isEmpty { amount = "0" }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target = target
        if trimmed.isEmpty { error = "Ponle un nombre."; return }
        if kind == .quantity && (target ?? 0) <= 0 { error = "Indica la cantidad objetivo."; return }
        if mode == .someDays && days.isEmpty { error = "Elige al menos un día."; return }
        error = nil
        saving = true
        defer { saving = false }
        var fields: [String: JSONValue] = [
            "name": .string(trimmed),
            "icon": .string(icon),
            "unit": kind == .check ? .null : .string(unit.trimmingCharacters(in: .whitespaces)),
            "period": .string(mode.weekly ? "week" : "day"),
            "target": target.map(JSONValue.double) ?? .null,
            "days_of_week": mode == .someDays ? .array(days.sorted().map(JSONValue.int)) : .null,
            "start_date": .string(CarliDate.isoDay(start)),
            "preferred_time": .optional(time),
            "show_in_tasks": .bool(showInTasks),
        ]
        if !editing { fields["kind"] = .string(kind.rawValue) }
        struct Saved: Decodable { var id: String }
        do {
            let saved: DataEnvelope<Saved>
            if let habit {
                saved = try await api.patch("v1/habits/\(habit.id)", body: Patch(fields))
            } else {
                saved = try await api.post("v1/habits", body: Patch(fields))
            }
            HabitActions.changed()
            dismiss()
            if !editing { onCreated(saved.data.id) }
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el hábito.")
        }
    }
}

struct HabitsSettingsView: View {
    let api: APIClient

    @State private var settings: HabitsSettings?
    @State private var breaks: [HabitBreak] = []
    @State private var breakSheet = false
    @State private var actions: HabitActions

    init(api: APIClient) {
        self.api = api
        _actions = State(initialValue: HabitActions(api: api))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Mostrar en Hoy de Tareas", isOn: Binding(
                    get: { settings?.showInTasks ?? true },
                    set: { value in save(["show_in_tasks": .bool(value)]) { $0.showInTasks = value } }))
                Toggle("Línea en el aviso de las 20:00", isOn: Binding(
                    get: { settings?.digest ?? true },
                    set: { value in save(["digest": .bool(value)]) { $0.digest = value } }))
                LabeledContent("Primer día de la semana", value: "Lunes")
                LabeledContent("Avisos por hábito", value: "Próximamente")
            } footer: {
                Text("Los hábitos nunca entran en Pendientes. A las 20:00 se avisa de los de hoy que faltan y de los semanales en riesgo.")
            }
            Section("Modo descanso") {
                ForEach(breaks.filter { $0.global && ($0.isActive || $0.isUpcoming) }) { pause in
                    LabeledContent(pause.isActive ? "En curso" : "Programado", value: pause.range)
                }
                Button(breaks.contains { $0.global && ($0.isActive || $0.isUpcoming) } ? "Gestionar descansos" : "Empezar un descanso") {
                    breakSheet = true
                }
            }
        }
        .navigationTitle("Ajustes de Hábitos")
        .task { await load() }
        .habitActions(actions)
        .sheet(isPresented: $breakSheet, onDismiss: { Task { await load() } }) { HabitBreakSheet(actions: actions) }
    }

    private func load() async {
        settings = await ModuleSettings.load(api, module: AppModule.habits, as: HabitsSettings.self) ?? HabitsSettings()
        if let list: DataEnvelope<[HabitBreak]> = try? await api.get("v1/habits/breaks") { breaks = list.data }
    }

    private func save(_ fields: [String: JSONValue], apply: (inout HabitsSettings) -> Void) {
        let previous = settings
        var next = settings ?? HabitsSettings()
        apply(&next)
        settings = next
        Task {
            do {
                try await ModuleSettings.save(api, module: AppModule.habits, fields)
                HabitActions.changed()
            } catch {
                settings = previous
                actions.toast = error.apiMessage(fallback: "No se han podido guardar los ajustes.")
            }
        }
    }
}
