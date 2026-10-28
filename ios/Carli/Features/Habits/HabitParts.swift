import SwiftUI

/// Every habit ring uses the first ring tone; the icon in the middle stays neutral.
let habitRingColor = CarliColor.rings[0]

struct HabitRing: View {
    var icon: String
    var progress: Double
    var size: CGFloat = 48
    var lineWidth: CGFloat = 6

    var body: some View {
        ActivityRing(progress: progress, color: habitRingColor, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: CarliIcon.symbol(icon))
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundStyle(CarliColor.text)
            }
    }
}

/// A ring that logs on tap and opens the log sheet on long press.
struct HabitRingButton: View {
    var today: HabitToday
    var actions: HabitActions
    var size: CGFloat = 48
    var lineWidth: CGFloat = 6

    var body: some View {
        HabitRing(icon: today.icon, progress: today.progress, size: size, lineWidth: lineWidth)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.circle)
            .onTapGesture { actions.tap(today) }
            .onLongPressGesture { actions.logging = HabitLogTarget(today: today) }
            .sensoryFeedback(.success, trigger: today.todayValue)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Registrar \(today.name), \(today.valueLabel)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { actions.tap(today) }
            .accessibilityAction(named: "Registrar una cantidad") { actions.logging = HabitLogTarget(today: today) }
    }
}

/// Compact rings to log without opening Hábitos (Inicio, Tareas · Hoy).
struct HabitRingStrip: View {
    var habits: [HabitToday]
    var actions: HabitActions

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: CarliSpace.s8) {
                ForEach(habits) { habit in
                    VStack(spacing: CarliSpace.s4) {
                        HabitRingButton(today: habit, actions: actions, size: 52)
                        Group {
                            Text(habit.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(CarliColor.text)
                            Text(habit.valueLabel)
                                .font(.caption2)
                                .foregroundStyle(CarliColor.text2)
                        }
                        .lineLimit(1)
                        .accessibilityHidden(true)
                    }
                    .frame(width: 72)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// One day of a habit as a small mark: filled when met, outlined when missed, ringed today.
struct DayDot: View {
    var state: DayState
    var size: CGFloat = 14
    var square = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: square ? size * 0.3 : size / 2, style: .continuous)
        let faint = CarliColor.text3.opacity(0.35)
        ZStack {
            switch state {
            case .done: shape.fill(habitRingColor)
            case .miss: shape.strokeBorder(CarliColor.text3, lineWidth: 1.5)
            case .today: shape.strokeBorder(habitRingColor, lineWidth: 2)
            case .rest: shape.fill(CarliColor.surface2).overlay(shape.strokeBorder(faint, lineWidth: 1))
            case .future: Circle().fill(faint).frame(width: size * 0.4, height: size * 0.4)
            case .off:
                if square { shape.fill(CarliColor.surface2) } else { Capsule().fill(faint).frame(width: size * 0.55, height: 2) }
            case .none: Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(state.label)
    }
}

// MARK: Log sheet

/// Long press on a ring, or a day of the calendar: − / + around a big ring, the exact value, the day and a note.
struct HabitLogSheet: View {
    var actions: HabitActions
    var target: HabitLogTarget

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double
    @State private var date: Date
    @State private var note: String
    @State private var exact: String
    @State private var saving = false
    @State private var pickingDay = false

    init(actions: HabitActions, target: HabitLogTarget) {
        self.actions = actions
        self.target = target
        _value = State(initialValue: target.value)
        _date = State(initialValue: target.date)
        _note = State(initialValue: target.note ?? "")
        _exact = State(initialValue: HabitFormat.number(target.value))
    }

    private var habit: Habit { target.habit }
    private var check: Bool { habit.kind == .check }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        stepButton("minus", "Quitar uno", enabled: value > 0) { set(check ? 0 : value - 1) }
                        Spacer()
                        ActivityRing(progress: progress, color: habitRingColor, lineWidth: 16)
                            .frame(width: 150, height: 150)
                            .overlay {
                                VStack(spacing: 0) {
                                    Text(HabitFormat.number(value))
                                        .font(.system(size: 44, weight: .bold))
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                    Text(caption).font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(HabitFormat.number(value)) \(caption)")
                        Spacer()
                        stepButton("plus", "Añadir uno", enabled: !(check && value >= 1)) { set(value + 1) }
                    }
                    .padding(.vertical, CarliSpace.s8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    if !check {
                        LabeledContent("Valor exacto") {
                            TextField("0", text: $exact)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: exact) { _, text in
                                    if let parsed = Double(text.replacingOccurrences(of: ",", with: ".")), parsed >= 0 { value = parsed }
                                }
                        }
                    }
                    Button { pickingDay = true } label: {
                        LabeledContent("Día", value: CarliDate.calendar.isDateInToday(date) ? "Hoy" : CarliDate.short(date))
                    }
                    .disabled(!target.canChangeDay)
                    .foregroundStyle(CarliColor.text)
                    TextField("Nota (opcional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Guardar", systemImage: "checkmark") { Task { await save() } }
                            .buttonStyle(.glassProminent)
                            .tint(CarliColor.primary)
                    }
                }
            }
            .sheet(isPresented: $pickingDay) {
                NavigationStack {
                    DatePicker("Día", selection: $date, in: habit.start...Date.now, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Listo") { pickingDay = false } }
                        }
                }
                .presentationDetents([.medium])
            }
        }
        .presentationDetents([.large])
    }

    private var progress: Double {
        let goal = target.target
        if habit.kind == .avoid { return goal <= 0 ? (value > 0 ? 1 : 0) : value / goal }
        return goal <= 0 ? 1 : value / goal
    }

    private var caption: String {
        let unit = habit.unit?.trimmingCharacters(in: .whitespaces) ?? ""
        switch habit.kind {
        case .check: return value > 0 ? "hecho" : "sin hacer"
        case .quantity: return "de \(HabitFormat.amount(target.target, unit))"
        case .avoid: return target.target <= 0 ? (unit.isEmpty ? "veces" : unit) : "de \(HabitFormat.amount(target.target, unit)) como máximo"
        }
    }

    private func set(_ next: Double) {
        withAnimation(.snappy) { value = max(0, next) }
        exact = HabitFormat.number(value)
    }

    private func stepButton(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func save() async {
        saving = true
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = await actions.log(habit, previous: target.value, value: value, date: date,
                                      note: trimmed.isEmpty ? nil : trimmed)
        saving = false
        if saved { dismiss() }
    }
}

// MARK: Breaks

/// "Modo descanso": the breaks in course with "Terminar", and a new one from today (or for one habit only).
struct HabitBreakSheet: View {
    var actions: HabitActions
    var habit: Habit?

    @Environment(\.dismiss) private var dismiss
    @State private var breaks: [HabitBreak] = []
    @State private var from = CarliDate.calendar.startOfDay(for: .now)
    @State private var to = CarliDate.calendar.date(byAdding: .day, value: 6, to: CarliDate.calendar.startOfDay(for: .now))!
    @State private var saving = false

    private var today: Date { CarliDate.calendar.startOfDay(for: .now) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(breaks.filter { ($0.isActive || $0.isUpcoming) && $0.habitId == habit?.id }) { pause in
                        LabeledContent("\(pause.isActive ? "En curso" : "Programado") · \(pause.range)") {
                            Button(pause.isActive ? "Terminar" : "Quitar") {
                                Task {
                                    await actions.endBreak(pause)
                                    await load()
                                }
                            }
                        }
                    }
                } footer: {
                    Text(habit == nil
                         ? "Vacaciones, enfermo… Mientras dure no se evalúa ningún hábito: ni rompe rachas ni baja la constancia."
                         : "Mientras dure no se evalúa este hábito: ni rompe la racha ni baja la constancia.")
                }
                Section("Nuevo descanso") {
                    HStack(spacing: CarliSpace.s8) {
                        ForEach([(3, "3 días"), (7, "1 semana"), (14, "2 semanas")], id: \.0) { days, label in
                            let end = CarliDate.calendar.date(byAdding: .day, value: days - 1, to: today)!
                            Chip(label: label, selected: from == today && CarliDate.calendar.isDate(to, inSameDayAs: end)) {
                                from = today
                                to = end
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    DatePicker("Desde", selection: $from, displayedComponents: .date)
                        .onChange(of: from) { _, value in if to < value { to = value } }
                    DatePicker("Hasta", selection: $to, in: from..., displayedComponents: .date)
                }
            }
            .navigationTitle(habit.map { "Descanso de \($0.name)" } ?? "Modo descanso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Empezar") {
                            Task {
                                saving = true
                                let saved = await actions.startBreak(from: from, to: to, habitId: habit?.id)
                                saving = false
                                if saved { dismiss() }
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(CarliColor.primary)
                    }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        if let list: DataEnvelope<[HabitBreak]> = try? await actions.api.get("v1/habits/breaks") { breaks = list.data }
    }
}

// MARK: Template conversion

/// Turns a daily or weekly task template into a habit, importing its last 8 weeks.
struct ConvertTemplateSheet: View {
    let api: APIClient
    var templateId: String
    var onDone: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var preview: ConversionPreview?
    @State private var failed: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                if let preview {
                    content(preview)
                } else if let failed {
                    ContentUnavailableView("No se puede convertir esta plantilla", systemImage: "exclamationmark.circle",
                                           description: Text(failed))
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Convertir en hábito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Convertir") { Task { await convert() } }
                            .disabled(preview == nil)
                    }
                }
            }
            .task {
                do {
                    let envelope: DataEnvelope<ConversionPreview> = try await api.get("v1/habits/conversions/\(templateId)")
                    preview = envelope.data
                } catch {
                    failed = error.apiMessage(fallback: "Inténtalo de nuevo.")
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func content(_ preview: ConversionPreview) -> some View {
        Section {
            LabeledContent("Objetivo", value: preview.goalText ?? "")
            LabeledContent("Tipo", value: HabitKind.check.label)
        } footer: {
            Text("Dejará de generar tareas. Lo seguirás en Hábitos y como anillo en Hoy.")
        }
        Section {
            let cells = preview.cells ?? []
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<((cells.count + 6) / 7), id: \.self) { row in
                    GridRow {
                        ForEach(Array(cells.dropFirst(row * 7).prefix(7).enumerated()), id: \.offset) { _, cell in
                            DayDot(state: cell.state, size: 22, square: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            Text("\(preview.done ?? 0) hechas · \(preview.skipped ?? 0) saltadas → descanso · \(preview.missed ?? 0) sin hacer")
                .font(.footnote)
        } header: {
            Text("Historial que se importa · 8 semanas")
        } footer: {
            Text("Empiezas con constancia del \(HabitFormat.percent(preview.consistency)) y racha de \(HabitFormat.streakLength(preview.streak ?? 0, weekly: false)). La plantilla queda pausada y se borra la tarea abierta de hoy. Subtareas, lista y notas no pasan al hábito.")
        }
    }

    private func convert() async {
        saving = true
        defer { saving = false }
        struct Payload: Encodable { var templateId: String }
        do {
            let _: Empty = try await api.post("v1/habits/conversions", body: Payload(templateId: templateId))
            HabitActions.changed()
            NotificationCenter.default.post(name: .tasksChanged, object: nil)
            onDone("Convertida en hábito")
            dismiss()
        } catch {
            failed = error.apiMessage(fallback: "No se ha podido convertir la plantilla.")
        }
    }
}
