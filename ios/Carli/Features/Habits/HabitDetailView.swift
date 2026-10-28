import SwiftUI

struct HabitDetailView: View {
    let api: APIClient
    var habitId: String

    @Environment(\.dismiss) private var dismiss
    @State private var detail: HabitDetail?
    @State private var failed: String?
    @State private var editing = false
    @State private var breakSheet = false
    @State private var confirmingDelete = false
    @State private var actions: HabitActions

    init(api: APIClient, habitId: String) {
        self.api = api
        self.habitId = habitId
        _actions = State(initialValue: HabitActions(api: api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s16) {
                if let detail {
                    content(detail)
                } else if let failed {
                    ContentUnavailableView {
                        Label("No se ha podido cargar el hábito", systemImage: "exclamationmark.circle")
                    } description: { Text(failed) } actions: {
                        Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, CarliSpace.s48)
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s48)
        }
        .background(CarliColor.bg)
        .navigationTitle(detail?.habit.name ?? "Hábito")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if detail != nil {
                ToolbarItem(placement: .topBarTrailing) { Button("Editar") { editing = true } }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onHabitsChanged { await load() }
        .habitActions(actions)
        .sheet(isPresented: $editing) {
            if let detail { HabitEditorView(api: api, habit: detail.habit) }
        }
        .sheet(isPresented: $breakSheet) {
            if let detail { HabitBreakSheet(actions: actions, habit: detail.habit) }
        }
        .confirmationDialog("Borrar \(detail?.habit.name ?? "")", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                Task {
                    if let habit = detail?.habit, await actions.delete(habit) { dismiss() }
                }
            }
        } message: {
            Text("Se borra el hábito con todo su historial. Si solo quieres dejarlo, archívalo.")
        }
    }

    @ViewBuilder
    private func content(_ detail: HabitDetail) -> some View {
        let habit = detail.habit
        let weekly = habit.goal.weekly
        let status = habit.status == .paused ? " · pausado" : habit.status == .archived ? " · archivado" : ""
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: CarliIcon.symbol(habit.icon))
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .background(CarliColor.surface2, in: .rect(cornerRadius: CarliRadius.control, style: .continuous))
            Text("\(habit.isAvoid ? "Evitar · " : "")\(habit.goalText) · \(HabitFormat.since(habit.start))\(status)")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
        }
        .foregroundStyle(CarliColor.text)

        CarliCard {
            HStack(alignment: .top) {
                stat("CONSTANCIA", HabitFormat.percent(detail.stats.consistency), "últimas 4 semanas", large: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                stat(habit.isAvoid ? "SIN PASARTE" : "RACHA", HabitFormat.streakLength(detail.stats.streak ?? 0, weekly: weekly),
                     "en curso")
                    .frame(maxWidth: .infinity, alignment: .leading)
                stat("MEJOR", HabitFormat.streakLength(detail.stats.bestStreak ?? 0, weekly: weekly),
                     detail.stats.bestStreakEnd.flatMap(CarliDate.day).map {
                         CarliDate.months[CarliDate.calendar.component(.month, from: $0) - 1]
                     } ?? "—")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        Text("Desde el inicio: \(HabitFormat.percent(detail.stats.consistencyAll))")
            .font(.footnote)
            .foregroundStyle(CarliColor.text2)
            .padding(.horizontal, CarliSpace.s4)

        HabitCalendarCard(api: api, habit: habit, actions: actions)

        if weekly || habit.kind == .quantity || !detail.weeks.isEmpty {
            WeekBarsCard(habit: habit, weeks: detail.weeks.filter { week in
                guard let start = CarliDate.day(week.start),
                      let end = CarliDate.calendar.date(byAdding: .day, value: 6, to: start) else { return true }
                return end >= CarliDate.calendar.startOfDay(for: habit.start)
            })
        }

        VStack(spacing: 0) {
            if !habit.isAvoid {
                Toggle("Mostrar en Hoy de Tareas", isOn: Binding(
                    get: { habit.showInTasks },
                    set: { value in
                        self.detail?.habit.showInTasks = value
                        Task { await actions.setShowInTasks(habit, value) }
                    }))
                    .padding(.horizontal, CarliSpace.s16)
                    .padding(.vertical, 10)
                Divider().padding(.leading, CarliSpace.s16)
            }
            actionRow("Descanso de este hábito", chevron: true) { breakSheet = true }
            if habit.status != .archived {
                Divider().padding(.leading, CarliSpace.s16)
                actionRow(habit.status == .paused ? "Reanudar" : "Pausar") {
                    Task { await actions.transition(habit, habit.status == .paused ? "resume" : "pause") }
                }
            }
            Divider().padding(.leading, CarliSpace.s16)
            actionRow(habit.status == .archived ? "Desarchivar" : "Archivar") {
                Task { await actions.transition(habit, habit.status == .archived ? "unarchive" : "archive") }
            }
        }
        .foregroundStyle(CarliColor.text)
        .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.card, style: .continuous))

        Button(role: .destructive) { confirmingDelete = true } label: {
            Text("Borrar hábito").frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .foregroundStyle(CarliColor.negative)
        .controlSize(.large)
    }

    private func stat(_ label: String, _ value: String, _ caption: String, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(CarliColor.text2)
            Text(value)
                .font(large ? .system(size: 34, weight: .bold) : .title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 40, alignment: .leading)
            Text(caption).font(.caption).foregroundStyle(CarliColor.text2)
        }
        .foregroundStyle(CarliColor.text)
        .accessibilityElement(children: .combine)
    }

    private func actionRow(_ title: String, chevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if chevron { Chevron() }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<HabitDetail> = try await api.get("v1/habits/\(habitId)")
            detail = envelope.data
            failed = nil
        } catch {
            if detail == nil { failed = error.apiMessage(fallback: "Inténtalo de nuevo.") }
        }
    }
}

/// Month grid: tap a past day to mark it (yes/no) or to open the log sheet for that day.
private struct HabitCalendarCard: View {
    let api: APIClient
    var habit: Habit
    var actions: HabitActions

    @State private var month = CarliDate.calendar.date(from: CarliDate.calendar.dateComponents([.year, .month], from: .now))!
    @State private var days: [CalendarDay] = []

    private var calendar: Calendar { CarliDate.calendar }

    var body: some View {
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: habit.start))!
        let blanks = FrequencyDraft.isoWeekday(month) - 1
        let c = calendar.dateComponents([.year, .month], from: month)
        CarliCard {
            VStack(spacing: CarliSpace.s12) {
                HStack {
                    Button("Mes anterior", systemImage: "chevron.left") { shift(-1) }
                        .labelStyle(.iconOnly)
                        .disabled(month <= first)
                    Spacer()
                    Text("\(CarliDate.months[c.month! - 1].capitalizedFirst) \(String(c.year!))").font(.headline)
                    Spacer()
                    Button("Mes siguiente", systemImage: "chevron.right") { shift(1) }
                        .labelStyle(.iconOnly)
                        .disabled(month >= current)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                    ForEach(TaskDates.weekdaysMondayFirst.indices.map { "weekday-\($0)" }, id: \.self) { key in
                        Text(TaskDates.weekdaysMondayFirst[Int(key.dropFirst(8))!])
                            .font(.system(size: 11))
                            .foregroundStyle(CarliColor.text2)
                            .accessibilityHidden(true)
                    }
                    ForEach((0..<blanks).map { "blank-\($0)" }, id: \.self) { _ in Color.clear.frame(height: 36) }
                    ForEach(days) { day in cell(day) }
                }
                HStack(spacing: CarliSpace.s16) {
                    legend(Circle().fill(habitRingColor), "Hecho")
                    legend(Circle().strokeBorder(CarliColor.text3, lineWidth: 1.5), "No hecho")
                    legend(Circle().fill(CarliColor.surface2), "Descanso")
                    Spacer()
                }
                .accessibilityHidden(true)
            }
            .foregroundStyle(CarliColor.text)
        }
        .task(id: month) { await load() }
        .onHabitsChanged { await load() }
    }

    private func cell(_ day: CalendarDay) -> some View {
        let number = CarliDate.day(day.date).map { calendar.component(.day, from: $0) } ?? 0
        let tappable = day.state != .future && day.state != .none
        let strong = day.state == .today || day.state == .done
        return Button { open(day) } label: {
            Text("\(number)")
                .font(.footnote.weight(strong ? .bold : .regular))
                .foregroundStyle(day.state == .done ? CarliColor.onBrand
                                 : day.state == .rest ? CarliColor.text2
                                 : tappable ? CarliColor.text : CarliColor.text3)
                .frame(width: 36, height: 36)
                .background {
                    switch day.state {
                    case .done: Circle().fill(habitRingColor)
                    case .miss: Circle().strokeBorder(CarliColor.text3, lineWidth: 1.5)
                    case .today: Circle().strokeBorder(habitRingColor, lineWidth: 2)
                    case .rest: Circle().fill(CarliColor.surface2)
                    default: Color.clear
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
        .accessibilityLabel("\(number) de \(CarliDate.months[calendar.component(.month, from: month) - 1]), \(day.state.label)\(day.value > 0 ? ", \(HabitFormat.number(day.value))" : "")")
    }

    private func legend(_ mark: some View, _ label: String) -> some View {
        HStack(spacing: 5) {
            mark.frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(CarliColor.text2)
        }
    }

    private func open(_ day: CalendarDay) {
        guard let date = CarliDate.day(day.date) else { return }
        if habit.kind == .check {
            Task { await actions.log(habit, previous: day.value, value: day.value > 0 ? 0 : 1, date: date, note: day.note) }
        } else {
            actions.logging = HabitLogTarget(habit: habit, date: date, value: day.value, target: habit.goal.target,
                                             note: day.note, canChangeDay: false)
        }
    }

    private func shift(_ months: Int) {
        month = calendar.date(byAdding: .month, value: months, to: month) ?? month
    }

    private func load() async {
        let key = String(CarliDate.isoDay(month).prefix(7))
        if let envelope: DataEnvelope<HabitCalendar> = try? await api.get("v1/habits/\(habit.id)/calendar", query: ["month": key]) {
            days = envelope.data.days
        }
    }
}

/// The last weeks as bars; a week that met its target uses the ring tone.
private struct WeekBarsCard: View {
    var habit: Habit
    var weeks: [WeekBar]

    var body: some View {
        let unit = habit.unit ?? ""
        let title = switch habit.kind {
        case .quantity: unit.isEmpty ? "Por semana" : "\(unit.capitalizedFirst) por semana"
        case .check where habit.goal.weekly: "Veces por semana"
        default: "Días por semana"
        }
        let top = weeks.reduce(1.0) { max($0, $1.value, $1.target) }
        CarliCard {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                Text(title).font(.subheadline.weight(.semibold))
                HStack(alignment: .bottom, spacing: CarliSpace.s8) {
                    ForEach(weeks, id: \.start) { week in
                        VStack(spacing: CarliSpace.s4) {
                            Text(HabitFormat.number(week.value)).font(.system(size: 11)).foregroundStyle(CarliColor.text2)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(week.target > 0 && week.value + 0.001 >= week.target ? habitRingColor : CarliColor.text)
                                .frame(height: min(64, max(4, week.value / top * 64)))
                        }
                        .frame(maxWidth: 40)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Semana del \(CarliDate.day(week.start).map(HabitFormat.dayPhrase) ?? week.start): \(HabitFormat.number(week.value)) de \(HabitFormat.number(week.target))")
                    }
                }
                .frame(height: 96, alignment: .bottom)
                if let first = weeks.first.flatMap({ CarliDate.day($0.start) }) {
                    HStack {
                        Text(CarliDate.short(first))
                        Spacer()
                        Text("esta semana")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(CarliColor.text2)
                    .accessibilityHidden(true)
                }
            }
            .foregroundStyle(CarliColor.text)
        }
    }
}
