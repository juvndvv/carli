import SwiftUI

/// Inicio › Calendario, laid out like Google Calendar on the phone: agenda, day, three days,
/// week, month or year. Mixes Google events with tasks, scheduled tasks, expected charges,
/// weigh-ins and habits.
struct CalendarView: View {
    let api: APIClient

    @Environment(AppRouter.self) private var router
    /// The layout is a preference and is remembered; the source filters reset on entering, like every filter in carli.
    @AppStorage("calendar.mode") private var mode: CalendarMode = .agenda
    @State private var store: CalendarStore
    @State private var selected = CalendarLayout.startOfDay(.now)
    @State private var hidden: Set<CalendarSource> = []
    @State private var event: CalendarItem?
    @State private var adding = false
    @State private var toast: String?
    @State private var busy: String?
    /// Months the agenda has scrolled through, from the selected one.
    @State private var agendaMonths = 2

    init(api: APIClient) {
        self.api = api
        _store = State(initialValue: CalendarStore(api: api))
    }

    var body: some View {
        VStack(spacing: 0) {
            googleNotice
            if mode != .agenda { periodBar }
            content
        }
        .background(CarliColor.bg)
        .toolbar { toolbar }
        .refreshable { await store.load(neededMonths, force: true) }
        .task(id: neededMonths) { await store.load(neededMonths, force: false) }
        .onTasksChanged { await store.reloadAll(also: neededMonths) }
        .onHealthChanged { await store.reloadAll(also: neededMonths) }
        .onHabitsChanged { await store.reloadAll(also: neededMonths) }
        .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in
            Task {
                store.reset()
                await store.load(neededMonths, force: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in
            Task { await store.reloadAll(also: neededMonths) }
        }
        .onChange(of: mode) { agendaMonths = 2 }
        .sheet(item: $event) { EventDetailSheet(item: $0) }
        .sheet(isPresented: $adding) {
            NewTaskSheet(api: api, date: selected, onSaved: { toast = $0 })
        }
        .carliToast($toast)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let failed = store.failed, !neededMonths.allSatisfy(store.isLoaded) {
            ContentUnavailableView {
                Label("No se ha podido cargar el calendario", systemImage: "exclamationmark.circle")
            } description: { Text(failed) } actions: {
                Button("Reintentar") { Task { await store.load(neededMonths, force: true) } }.buttonStyle(.glass)
            }
            .frame(maxHeight: .infinity)
        } else {
            switch mode {
            case .agenda:
                CalendarAgenda(
                    months: agendaKeys,
                    selected: selected,
                    loaded: agendaKeys.allSatisfy(store.isLoaded),
                    items: visible,
                    busy: busy,
                    toggle: { item in Task { await toggle(item) } },
                    showEvent: { event = $0 },
                    more: { if agendaMonths < 24 { agendaMonths += 1 } }
                )
            case .day, .threeDays, .week:
                CalendarTimeline(
                    days: CalendarLayout.days(mode, around: selected),
                    items: visible,
                    pickDay: { day in pick(day, as: .day) },
                    showEvent: { event = $0 }
                )
                .id(mode)
                .simultaneousGesture(swipe)
            case .month:
                CalendarMonthGrid(
                    month: CalendarLayout.firstOfMonth(selected),
                    days: CalendarLayout.days(.month, around: selected),
                    items: visible,
                    pickDay: { day in pick(day, as: .day) }
                )
                .simultaneousGesture(swipe)
            case .year:
                CalendarYearGrid(
                    year: CalendarLayout.firstOfYear(selected),
                    pickMonth: { month in pick(month, as: .month) }
                )
                .simultaneousGesture(swipe)
            }
        }
    }

    private var periodBar: some View {
        HStack(spacing: CarliSpace.s16) {
            Text(CalendarLayout.title(mode, selected: selected))
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .contentTransition(.numericText())
            if !neededMonths.allSatisfy(store.isLoaded), store.failed == nil {
                ProgressView().controlSize(.small)
            }
            Spacer()
            Button("Anterior", systemImage: "chevron.left") { move(-1) }
                .labelStyle(.iconOnly)
            Button("Siguiente", systemImage: "chevron.right") { move(1) }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .foregroundStyle(CarliColor.text2)
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s8)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            move(value.translation.width < 0 ? 1 : -1)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Vista", selection: $mode.animation(.snappy)) {
                    ForEach(CalendarMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                Section("Mostrar") {
                    ForEach(CalendarSource.allCases) { source in
                        Toggle(isOn: Binding(get: { !hidden.contains(source) }, set: { on in
                            if on { hidden.remove(source) } else { hidden.insert(source) }
                        })) {
                            Label(source.label, systemImage: source.symbol)
                        }
                    }
                }
                Section {
                    Button("Calendarios de Google", systemImage: "gearshape") {
                        _ = router.open(url: "/ajustes/calendarios")
                    }
                }
            } label: {
                Image(systemName: mode.symbol)
                    .overlay(alignment: .topTrailing) {
                        if !hidden.isEmpty {
                            Circle().fill(CarliColor.primary).frame(width: 6, height: 6).offset(x: 4, y: -3)
                        }
                    }
            }
            .accessibilityLabel("Vista: \(mode.label)\(hidden.isEmpty ? "" : ", \(hidden.count) fuentes ocultas")")
        }
        if !CarliDate.calendar.isDateInToday(selected) {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Hoy") { withAnimation(.snappy) { selected = CalendarLayout.startOfDay(.now) } }
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button { adding = true } label: {
                Image(systemName: "plus").foregroundStyle(CarliColor.onPrimary)
            }
            .buttonStyle(.glassProminent)
            .tint(CarliColor.primary)
            .accessibilityLabel("Nueva tarea")
        }
    }

    @ViewBuilder
    private var googleNotice: some View {
        if let google = store.google {
            if !google.reconnect.isEmpty {
                notice("Vuelve a conectar \(google.reconnect.joined(separator: ", ")). Sus eventos no se actualizan.",
                       symbol: "exclamationmark.triangle", color: CarliColor.negative)
            } else if google.accounts == 0 && !hidden.contains(.google) {
                notice("Conecta Google Calendar para ver aquí tus eventos", symbol: "calendar.badge.plus", color: CarliColor.text2)
            }
        }
    }

    private func notice(_ text: String, symbol: String, color: Color) -> some View {
        NavigationLink(value: SettingsPage.calendars) {
            HStack {
                Label(text, systemImage: symbol)
                    .font(.footnote)
                    .foregroundStyle(color)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Chevron()
            }
            .padding(CarliSpace.s12)
            .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.control))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, CarliSpace.s16)
        .padding(.top, CarliSpace.s8)
    }

    // MARK: Data

    private var agendaKeys: [String] {
        (0..<agendaMonths).map { CalendarLayout.monthKey(CalendarLayout.step(.month, from: selected, by: $0)) }
    }

    /// Months of items the current mode needs. The year view draws no items.
    private var neededMonths: [String] {
        switch mode {
        case .agenda: agendaKeys
        case .year: []
        default: CalendarLayout.monthKeys(for: CalendarLayout.days(mode, around: selected))
        }
    }

    private func visible(_ day: Date) -> [CalendarItem] {
        store.items(on: day).filter { item in
            guard let kind = item.kind else { return false }
            return !hidden.contains(kind)
        }
    }

    private func move(_ direction: Int) {
        withAnimation(.snappy) { selected = CalendarLayout.step(mode, from: selected, by: direction) }
    }

    private func pick(_ day: Date, as next: CalendarMode) {
        withAnimation(.snappy) {
            selected = day
            mode = next
        }
    }

    private func toggle(_ item: CalendarItem) async {
        let id = item.meta?.taskId ?? item.id
        busy = item.id
        defer { busy = nil }
        do {
            let _: Empty = try await api.post("v1/tasks/tasks/\(id)/\(item.done ? "reopen" : "complete")")
            NotificationCenter.default.post(name: .tasksChanged, object: nil)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido cambiar la tarea.")
        }
    }
}

/// What tapping a calendar item does: tasks and scheduled tasks open in Tareas, Google events
/// open their sheet, the rest follow their link.
struct CalendarItemLink<Label: View>: View {
    var item: CalendarItem
    var showEvent: (CalendarItem) -> Void
    @ViewBuilder var label: Label

    @Environment(AppRouter.self) private var router

    var body: some View {
        switch item.kind {
        case .tasks:
            NavigationLink(value: TaskRoute(id: item.meta?.taskId ?? item.id)) { label }
                .buttonStyle(.plain)
        case .templates where item.meta?.templateId != nil:
            NavigationLink(value: TemplateRoute(id: item.meta?.templateId)) { label }
                .buttonStyle(.plain)
        case .google:
            Button { showEvent(item) } label: { label }
                .buttonStyle(.plain)
        default:
            Button { _ = router.open(url: item.url) } label: { label }
                .buttonStyle(.plain)
                .disabled(item.url == nil)
        }
    }
}

/// A Google event, read-only: Google stays the place to change it.
struct EventDetailSheet: View {
    var item: CalendarItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: CarliSpace.s8) {
                        HStack(spacing: CarliSpace.s8) {
                            Circle().fill(item.tint ?? CarliColor.text3).frame(width: 10, height: 10)
                            Text(item.meta?.calendar ?? "Google Calendar")
                                .font(.footnote)
                                .foregroundStyle(CarliColor.text2)
                        }
                        Text(item.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(CarliColor.text)
                        Text(when)
                            .font(.subheadline)
                            .foregroundStyle(CarliColor.text2)
                    }
                    .padding(.vertical, CarliSpace.s4)
                }
                if let location = item.meta?.location, !location.isEmpty {
                    Section {
                        Button {
                            if let url = URL(string: "maps://?q=\(location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") { openURL(url) }
                        } label: {
                            Label(location, systemImage: "mappin.and.ellipse")
                        }
                    }
                }
                if let meet = item.meta?.meetLink, let url = URL(string: meet) {
                    Section {
                        Button { openURL(url) } label: { Label("Unirse a la videollamada", systemImage: "video") }
                    }
                }
                if let description = item.meta?.description, !description.isEmpty {
                    Section("Notas") {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(CarliColor.text)
                            .textSelection(.enabled)
                    }
                }
                if let link = item.meta?.htmlLink, let url = URL(string: link) {
                    Section {
                        Button { openURL(url) } label: { Label("Abrir en Google Calendar", systemImage: "arrow.up.right.square") }
                    } footer: {
                        if let account = item.meta?.account { Text(account) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(CarliColor.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// "Martes, 4 de noviembre · 09:30 – 10:15", or the span of a multi-day event.
    private var when: String {
        let first = item.meta?.startDate.flatMap(CarliDate.day) ?? CarliDate.day(item.date) ?? .now
        let last = item.meta?.lastDate.flatMap(CarliDate.day) ?? first
        if !CarliDate.calendar.isDate(first, inSameDayAs: last) {
            return "Del \(CarliDate.short(first)) al \(CarliDate.short(last))"
        }
        let day = CarliDate.long(first)
        return item.allDay ? "\(day) · todo el día" : [day, item.timeRange].compactMap { $0 }.joined(separator: " · ")
    }
}
