import SwiftUI

struct HabitRoute: Hashable { var id: String }
struct HabitsSettingsRoute: Hashable {}

extension View {
    /// Pages every Hábitos section can push.
    func habitsDestinations(api: APIClient) -> some View {
        navigationDestination(for: HabitRoute.self) { HabitDetailView(api: api, habitId: $0.id) }
            .navigationDestination(for: HabitsSettingsRoute.self) { _ in HabitsSettingsView(api: api) }
    }
}

/// Title for a section inside a scrolling habits page.
private struct HabitSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CarliSpace.s8) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .padding(.horizontal, CarliSpace.s4)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// Rows inside one card, separated by inset dividers.
struct HabitGroup<Item: Identifiable, Row: View>: View {
    var items: [Item]
    var indent: CGFloat = 56
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, indent) }
                row(item)
            }
        }
        .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.card, style: .continuous))
    }
}

private struct LoadFailure: View {
    var title: String
    var message: String
    var retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.circle")
        } description: { Text(message) } actions: {
            Button("Reintentar") { Task { await retry() } }.buttonStyle(.glass)
        }
    }
}

// MARK: Hoy

struct HabitsTodayView: View {
    let api: APIClient
    var create: () -> Void

    @State private var view: HabitsToday?
    @State private var failed: String?
    @State private var breaks: [HabitBreak] = []
    @State private var breakSheet = false
    @State private var actions: HabitActions

    init(api: APIClient, create: @escaping () -> Void) {
        self.api = api
        self.create = create
        _actions = State(initialValue: HabitActions(api: api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s20) {
                if let view {
                    content(view)
                } else if let failed {
                    LoadFailure(title: "No se han podido cargar los hábitos", message: failed) { await load() }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, CarliSpace.s48)
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s48)
        }
        .background(CarliColor.bg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HabitsSettingsRoute()) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Ajustes de Hábitos")
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onHabitsChanged { await load() }
        .habitsDestinations(api: api)
        .habitActions(actions)
        .sheet(isPresented: $breakSheet, onDismiss: { Task { await load() } }) {
            HabitBreakSheet(actions: actions)
        }
    }

    @ViewBuilder
    private func content(_ view: HabitsToday) -> some View {
        Text(CarliDate.day(view.date).map(CarliDate.long) ?? "")
            .font(.footnote)
            .foregroundStyle(CarliColor.text2)
            .padding(.horizontal, CarliSpace.s4)

        if view.onBreak == true {
            Button { breakSheet = true } label: {
                CarliCard {
                    HStack(spacing: CarliSpace.s12) {
                        Image(systemName: "moon.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Modo descanso").font(.headline)
                            Text(breakLine).font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                        Spacer(minLength: 0)
                        Chevron()
                    }
                    .foregroundStyle(CarliColor.text)
                }
            }
            .buttonStyle(.plain)
        }

        if view.habits.isEmpty && view.onBreak != true {
            CarliCard {
                ContentUnavailableView {
                    Label("Nada para hoy", systemImage: "repeat")
                } description: {
                    Text("Crea un hábito con el botón + y lo verás aquí cada día que toque.")
                } actions: {
                    Button("Nuevo hábito", action: create).buttonStyle(.glass)
                }
            }
        }

        if view.summary.total > 0 {
            CarliCard {
                HStack(spacing: CarliSpace.s16) {
                    ActivityRing(progress: Double(view.summary.done) / Double(view.summary.total), color: habitRingColor,
                                 lineWidth: 10)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(view.summary.done) de \(view.summary.total)").font(.title2.weight(.bold)).monospacedDigit()
                        Text("hábitos cumplidos hoy").font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(HabitFormat.percent(view.summary.consistency)).font(.title3.weight(.semibold)).monospacedDigit()
                        Text("constancia").font(.caption).foregroundStyle(CarliColor.text2)
                    }
                }
                .foregroundStyle(CarliColor.text)
                .accessibilityElement(children: .combine)
            }
        }

        if !view.pending.isEmpty {
            HabitSection(title: "Por hacer") {
                VStack(spacing: CarliSpace.s8) {
                    ForEach(view.pending) { habit in pendingCard(habit) }
                }
            }
        }
        if !view.avoid.isEmpty {
            HabitSection(title: "Evitar") {
                HabitGroup(items: view.avoid) { habit in avoidRow(habit) }
            }
        }
        if !view.completed.isEmpty {
            HabitSection(title: "Hechos") {
                HabitGroup(items: view.completed) { habit in doneRow(habit) }
            }
        }
    }

    private var breakLine: String {
        guard let current = breaks.first(where: { $0.global && $0.isActive }), let to = CarliDate.day(current.toDate) else {
            return "Hoy no se evalúa ningún hábito."
        }
        return "Hasta el \(HabitFormat.dayPhrase(to)). No se evalúa nada."
    }

    private func pendingCard(_ habit: HabitToday) -> some View {
        CarliCard(padding: CarliSpace.s12) {
            HStack(spacing: CarliSpace.s12) {
                HabitRingButton(today: habit, actions: actions)
                NavigationLink(value: HabitRoute(id: habit.id)) {
                    HStack(spacing: CarliSpace.s8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name).font(.headline)
                            Text(HabitFormat.goalLine(habit)).font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(habit.valueLabel).font(.subheadline.weight(.semibold)).monospacedDigit()
                            Text(HabitFormat.streakLabel(habit.streakCount, weekly: habit.weekly))
                                .font(.caption).foregroundStyle(CarliColor.text2)
                        }
                    }
                    .foregroundStyle(CarliColor.text)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func avoidRow(_ habit: HabitToday) -> some View {
        let unit = habit.unit?.trimmingCharacters(in: .whitespaces) ?? ""
        let singular = unit.hasSuffix("s") ? String(unit.dropLast()) : unit
        let relapse = habit.target <= 0
        return HStack(spacing: CarliSpace.s12) {
            IconBubble(symbol: CarliIcon.symbol(habit.icon), size: 32)
            NavigationLink(value: HabitRoute(id: habit.id)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.name)
                    Text(habit.habit.goalText).font(.footnote).foregroundStyle(CarliColor.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            VStack(alignment: .trailing, spacing: CarliSpace.s4) {
                Text(habit.valueLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(habit.isOver ? CarliColor.negative : CarliColor.text)
                Button(relapse ? "Registrar recaída" : singular.isEmpty ? "+1" : "+1 \(singular)") { actions.tap(habit) }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
        }
        .foregroundStyle(CarliColor.text)
        .padding(.horizontal, CarliSpace.s12)
        .padding(.vertical, CarliSpace.s8)
    }

    private func doneRow(_ habit: HabitToday) -> some View {
        let canUndo = habit.todayValue > 0
        return HStack(spacing: CarliSpace.s12) {
            Button {
                if habit.habit.kind == .check { actions.tap(habit) } else { actions.logging = HabitLogTarget(today: habit) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CarliColor.onBrand)
                    .frame(width: 32, height: 32)
                    .background(habitRingColor, in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .accessibilityLabel(canUndo ? "Desmarcar \(habit.name)" : "\(habit.name), hecho")
            NavigationLink(value: HabitRoute(id: habit.id)) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(habit.name)
                        Text(HabitFormat.goalLine(habit)).font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                    Spacer(minLength: 0)
                    Text(HabitFormat.streakLabel(habit.streakCount, weekly: habit.weekly))
                        .font(.footnote).foregroundStyle(CarliColor.text2)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(CarliColor.text)
        .padding(.horizontal, CarliSpace.s12)
        .padding(.vertical, CarliSpace.s8)
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<HabitsToday> = try await api.get("v1/habits/today")
            view = envelope.data
            failed = nil
            if envelope.data.onBreak == true,
               let list: DataEnvelope<[HabitBreak]> = try? await api.get("v1/habits/breaks") {
                breaks = list.data
            }
        } catch {
            if view == nil { failed = error.apiMessage(fallback: "Inténtalo de nuevo.") }
        }
    }
}

// MARK: Lista

struct HabitsListView: View {
    let api: APIClient
    var create: () -> Void

    @State private var items: [HabitListItem]?
    @State private var failed: String?
    @State private var showPaused = false
    @State private var showArchived = false
    @State private var reordering = false
    @State private var breakSheet = false
    @State private var actions: HabitActions

    init(api: APIClient, create: @escaping () -> Void) {
        self.api = api
        self.create = create
        _actions = State(initialValue: HabitActions(api: api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s16) {
                if let items {
                    content(items)
                } else if let failed {
                    LoadFailure(title: "No se han podido cargar los hábitos", message: failed) { await load() }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, CarliSpace.s48)
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s48)
        }
        .background(CarliColor.bg)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Ordenar hábitos", systemImage: "arrow.up.arrow.down") { reordering = true }
                    .disabled(active.count < 2)
                Button("Modo descanso", systemImage: "moon") { breakSheet = true }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onHabitsChanged { await load() }
        .habitsDestinations(api: api)
        .habitActions(actions)
        .sheet(isPresented: $breakSheet) { HabitBreakSheet(actions: actions) }
        .sheet(isPresented: $reordering) { ReorderHabitsView(actions: actions, items: active) }
    }

    private var active: [HabitListItem] { (items ?? []).filter { $0.habit.status == .active } }

    @ViewBuilder
    private func content(_ items: [HabitListItem]) -> some View {
        let paused = items.filter { $0.habit.status == .paused }
        let archived = items.filter { $0.habit.status == .archived }
        if items.isEmpty {
            CarliCard {
                ContentUnavailableView {
                    Label("Sin hábitos todavía", systemImage: "repeat")
                } description: {
                    Text("Lo que importa aquí es la constancia, no la fecha. Empieza por uno o dos.")
                } actions: {
                    Button("Nuevo hábito", action: create).buttonStyle(.glass)
                }
            }
        } else {
            Text("\(active.count == 1 ? "1 ACTIVO" : "\(active.count) ACTIVOS") · SEMANA \(HabitFormat.isoWeek(.now))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CarliColor.text2)
                .padding(.horizontal, CarliSpace.s4)
            if !active.isEmpty {
                VStack(spacing: CarliSpace.s4) {
                    weekHeader
                    HabitGroup(items: active, indent: CarliSpace.s16) { row($0) }
                }
            }
            if active.count >= 7 {
                Text("Tienes \(active.count) hábitos activos. Con menos es más fácil mantenerlos: pausa alguno si te pesan.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .padding(.horizontal, CarliSpace.s4)
            }
            if !paused.isEmpty || !archived.isEmpty {
                VStack(spacing: 0) {
                    if !paused.isEmpty {
                        fold("Pausados · \(paused.count)", open: $showPaused)
                        if showPaused { ForEach(paused) { Divider().padding(.leading, CarliSpace.s16); row($0) } }
                    }
                    if !paused.isEmpty && !archived.isEmpty { Divider().padding(.leading, CarliSpace.s16) }
                    if !archived.isEmpty {
                        fold("Archivados · \(archived.count)", open: $showArchived)
                        if showArchived { ForEach(archived) { Divider().padding(.leading, CarliSpace.s16); row($0) } }
                    }
                }
                .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.card, style: .continuous))
            }
        }
    }

    private var weekHeader: some View {
        let today = FrequencyDraft.isoWeekday(.now)
        return HStack(spacing: 6) {
            Spacer()
            ForEach(1...7, id: \.self) { day in
                Text(TaskDates.weekdaysMondayFirst[day - 1])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(day == today ? CarliColor.text : CarliColor.text2)
                    .underline(day == today)
                    .frame(width: 18)
            }
            Text("4 sem")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CarliColor.text2)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, CarliSpace.s16)
        .accessibilityHidden(true)
    }

    private func row(_ item: HabitListItem) -> some View {
        let habit = item.habit
        let goal = habit.isAvoid ? "Evitar · \(habit.goalText.lowercased())" : habit.goalText
        return NavigationLink(value: HabitRoute(id: habit.id)) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name).font(.subheadline.weight(.semibold))
                    Text(goal).font(.caption).foregroundStyle(CarliColor.text2)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(item.week.enumerated()), id: \.offset) { _, cell in
                    DayDot(state: cell.state).frame(width: 18)
                }
                Text(HabitFormat.percent(item.consistency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .foregroundStyle(CarliColor.text)
            .padding(.horizontal, CarliSpace.s16)
            .padding(.vertical, CarliSpace.s12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(habit.name), \(goal), constancia \(HabitFormat.percent(item.consistency))")
        .accessibilityAddTraits(.isButton)
    }

    private func fold(_ label: String, open: Binding<Bool>) -> some View {
        Button { withAnimation(.snappy) { open.wrappedValue.toggle() } } label: {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: open.wrappedValue ? "chevron.up" : "chevron.down").font(.footnote.weight(.semibold))
            }
            .foregroundStyle(CarliColor.text2)
            .padding(.horizontal, CarliSpace.s16)
            .padding(.vertical, CarliSpace.s12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(open.wrappedValue ? "Desplegado" : "Plegado")
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[HabitListItem]> = try await api.get("v1/habits")
            items = envelope.data
            failed = nil
        } catch {
            if items == nil { failed = error.apiMessage(fallback: "Inténtalo de nuevo.") }
        }
    }
}

private struct ReorderHabitsView: View {
    var actions: HabitActions
    @State var items: [HabitListItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Label(item.habit.name, systemImage: CarliIcon.symbol(item.habit.icon))
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                    let ids = items.map(\.id)
                    Task { await actions.reorder(ids) }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ordenar hábitos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo", systemImage: "checkmark") { dismiss() } }
            }
        }
    }
}

// MARK: Progreso

struct HabitsProgressView: View {
    let api: APIClient

    @State private var range = ProgressRange.week
    @State private var progress: [ProgressRange: HabitsProgress] = [:]
    @State private var failed: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s16) {
                Picker("Periodo", selection: $range) {
                    ForEach(ProgressRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if let current = progress[range] {
                    content(current)
                } else if let failed {
                    LoadFailure(title: "No se ha podido cargar el progreso", message: failed) { await load() }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, CarliSpace.s48)
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s48)
        }
        .background(CarliColor.bg)
        .refreshable { await load() }
        .task(id: range) { await load() }
        .onHabitsChanged { progress = [:]; await load() }
        .habitsDestinations(api: api)
    }

    private func eyebrow(_ p: HabitsProgress) -> String {
        let from = CarliDate.day(p.from) ?? .now
        let to = CarliDate.day(p.to) ?? .now
        let c = CarliDate.calendar.dateComponents([.year, .month], from: from)
        switch p.kind {
        case .week: return "SEMANA \(HabitFormat.isoWeek(from)) · \(CarliDate.short(from)) – \(CarliDate.short(to))".uppercased()
        case .month: return "\(CarliDate.months[c.month! - 1]) \(c.year!)".uppercased()
        case .year: return "\(c.year!)"
        }
    }

    @ViewBuilder
    private func content(_ p: HabitsProgress) -> some View {
        Text(eyebrow(p))
            .font(.caption.weight(.semibold))
            .foregroundStyle(CarliColor.text2)
            .padding(.horizontal, CarliSpace.s4)
        CarliCard {
            HStack(spacing: CarliSpace.s16) {
                ActivityRing(progress: Double(p.consistency ?? 0) / 100, color: habitRingColor, lineWidth: 14)
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONSTANCIA GLOBAL").font(.caption.weight(.semibold)).foregroundStyle(CarliColor.text2)
                    Text(HabitFormat.percent(p.consistency)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                    if let trend = p.trend {
                        Text(trend == 0 ? "Igual que \(p.kind.previous)"
                             : "\(trend > 0 ? "↑" : "↓") \(abs(trend)) puntos frente a \(p.kind.previous)")
                            .font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                    Text("\(p.met ?? 0) de \(p.total ?? 0) periodos cumplidos").font(.footnote).foregroundStyle(CarliColor.text2)
                }
            }
            .foregroundStyle(CarliColor.text)
            .accessibilityElement(children: .combine)
        }
        if !p.habits.isEmpty { grid(p) }
        let ranking = p.habits.filter { $0.consistency != nil }.sorted { ($0.consistency ?? 0) > ($1.consistency ?? 0) }
        if !ranking.isEmpty {
            Text("Por constancia")
                .font(.title3.weight(.bold))
                .padding(.horizontal, CarliSpace.s4)
                .accessibilityAddTraits(.isHeader)
            HabitGroup(items: ranking, indent: CarliSpace.s16) { row in
                NavigationLink(value: HabitRoute(id: row.id)) {
                    HStack(spacing: CarliSpace.s12) {
                        Text(row.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(HabitFormat.trend(row.trend)).font(.footnote).monospacedDigit().foregroundStyle(CarliColor.text2)
                        Text(HabitFormat.percent(row.consistency))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                    .foregroundStyle(CarliColor.text)
                    .padding(.horizontal, CarliSpace.s16)
                    .padding(.vertical, 11)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func grid(_ p: HabitsProgress) -> some View {
        let week = p.kind == .week
        let year = p.kind == .year
        let columns = year ? 12 : (p.habits.first?.cells.count ?? 7)
        let headers: [String] = switch p.kind {
        case .week: TaskDates.weekdaysMondayFirst
        case .month: (1...max(columns, 1)).map { $0 == 1 || $0 % 5 == 0 ? "\($0)" : "" }
        case .year: CarliDate.monthsShort.map { String($0.prefix(1)).uppercased() }
        }
        let title = week ? "Esta semana" : year ? "Por meses" : "Este mes"
        return CarliCard {
            VStack(alignment: .leading, spacing: CarliSpace.s8) {
                Text(title).font(.subheadline.weight(.semibold))
                gridRow(week: week, leading: Text("")) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        Text(header).font(.system(size: 10)).foregroundStyle(CarliColor.text2).lineLimit(1).fixedSize()
                    }
                }
                .accessibilityHidden(true)
                ForEach(p.habits) { row in
                    gridRow(week: week, leading: Text(row.name).font(.footnote).lineLimit(1)) {
                        if year {
                            ForEach(Array(row.monthCells.enumerated()), id: \.offset) { _, value in
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(value.map { habitRingColor.opacity(0.15 + 0.85 * Double($0) / 100) } ?? CarliColor.surface2)
                                    .frame(width: 14, height: 14)
                            }
                        } else {
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                                DayDot(state: cell.state, size: week ? 18 : 8, square: true)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.name): \(row.met) de \(row.total) cumplidos")
                }
            }
            .foregroundStyle(CarliColor.text)
        }
    }

    private func gridRow<Cells: View>(week: Bool, leading: some View, @ViewBuilder cells: () -> Cells) -> some View {
        HStack(spacing: 0) {
            if week {
                leading.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                leading.frame(width: 84, alignment: .leading)
            }
            if week {
                Group(subviews: cells()) { subviews in
                    ForEach(subviews) { $0.frame(width: 26) }
                }
            } else {
                Group(subviews: cells()) { subviews in
                    ForEach(subviews) { $0.frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<HabitsProgress> = try await api.get("v1/habits/progress", query: ["range": range.rawValue])
            progress[range] = envelope.data
            failed = nil
        } catch {
            if progress[range] == nil { failed = error.apiMessage(fallback: "Inténtalo de nuevo.") }
        }
    }
}
