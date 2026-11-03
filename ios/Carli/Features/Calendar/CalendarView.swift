import SwiftUI

/// Inicio › Calendario: one week strip and the chosen day's agenda, mixing Google events
/// with tasks, scheduled tasks, expected charges, weigh-ins and habits.
struct CalendarView: View {
    let api: APIClient

    @Environment(AppRouter.self) private var router
    @State private var selected = CarliDate.calendar.startOfDay(for: .now)
    @State private var weeks: [String: CalendarRange] = [:]
    @State private var failed: String?
    /// Sources switched off in the filter menu; like every filter in carli, reset on entering.
    @State private var hidden: Set<CalendarSource> = []
    @State private var event: CalendarItem?
    @State private var adding = false
    @State private var toast: String?
    @State private var busy: String?

    var body: some View {
        List {
            Section {
                WeekHeader(selected: $selected, days: weekDays, marks: marks) { step in
                    move(weeks: step)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: CarliSpace.s4, trailing: CarliSpace.s4))

            if let range = currentRange {
                googleNotice(range.google)
                let items = visible(on: selected)
                if items.isEmpty {
                    Section {
                        Text(TaskDates.offset(selected) == 0 ? "Nada más para hoy." : "Nada este día.")
                            .font(.subheadline)
                            .foregroundStyle(CarliColor.text2)
                    }
                } else {
                    let allDay = items.filter(\.allDay)
                    let timed = items.filter { !$0.allDay }
                    if !allDay.isEmpty {
                        Section("Todo el día") { ForEach(allDay, id: \.key) { row($0) } }
                    }
                    if !timed.isEmpty {
                        Section(allDay.isEmpty ? "" : "Por horas") { ForEach(timed, id: \.key) { row($0) } }
                    }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se ha podido cargar el calendario", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await load(force: true) } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, CarliSpace.s4, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .toolbar { toolbar }
        .refreshable { await load(force: true) }
        .task(id: weekKey) { await load(force: false) }
        .onTasksChanged { await load(force: true) }
        .onHealthChanged { await load(force: true) }
        .onHabitsChanged { await load(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in Task { await reloadAll() } }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await load(force: true) } }
        .sheet(item: $event) { EventDetailSheet(item: $0) }
        .sheet(isPresented: $adding) {
            NewTaskSheet(api: api, date: selected, onSaved: { toast = $0 })
        }
        .carliToast($toast)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
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
                Image(systemName: hidden.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel(hidden.isEmpty ? "Filtrar" : "Filtrar (\(hidden.count) ocultos)")
        }
        if TaskDates.offset(selected) != 0 {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Hoy") { withAnimation { selected = CarliDate.calendar.startOfDay(for: .now) } }
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

    // MARK: Rows

    @ViewBuilder
    private func row(_ item: CalendarItem) -> some View {
        switch item.kind {
        case .tasks:
            HStack(spacing: CarliSpace.s4) {
                Button { Task { await toggle(item) } } label: {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.done ? CarliColor.primary : CarliColor.text3)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(busy == item.id)
                .accessibilityLabel(item.done ? "Marcar \(item.title) como pendiente" : "Marcar \(item.title) como hecha")
                .sensoryFeedback(.success, trigger: item.done)
                NavigationLink(value: TaskRoute(id: item.meta?.taskId ?? item.id)) { ItemLabel(item: item) }
            }
        case .templates:
            if let id = item.meta?.templateId {
                NavigationLink(value: TemplateRoute(id: id)) { ItemLabel(item: item) }
            } else {
                ItemLabel(item: item)
            }
        case .google:
            Button { event = item } label: { ItemLabel(item: item).contentShape(.rect) }
                .buttonStyle(.plain)
        default:
            Button { _ = router.open(url: item.url) } label: {
                HStack {
                    ItemLabel(item: item)
                    if item.url != nil { Chevron() }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func googleNotice(_ google: GoogleStatus) -> some View {
        if !google.reconnect.isEmpty {
            Section {
                NavigationLink(value: SettingsPage.calendars) {
                    Label("Vuelve a conectar \(google.reconnect.joined(separator: ", ")). Sus eventos no se actualizan.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.negative)
                }
            }
        } else if google.accounts == 0 && !hidden.contains(.google) {
            Section {
                NavigationLink(value: SettingsPage.calendars) {
                    Label("Conecta Google Calendar para ver aquí tus eventos", systemImage: "calendar.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
            }
        }
    }

    // MARK: Data

    private var weekStart: Date { Self.monday(of: selected) }
    private var weekKey: String { CarliDate.isoDay(weekStart) }
    private var currentRange: CalendarRange? { weeks[weekKey] }

    private var weekDays: [Date] {
        (0..<7).compactMap { CarliDate.calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Days of the shown week that have something visible.
    private var marks: Set<String> {
        Set((currentRange?.items ?? []).filter { isVisible($0) }.map(\.date))
    }

    private func isVisible(_ item: CalendarItem) -> Bool {
        guard let kind = item.kind else { return false }
        return !hidden.contains(kind)
    }

    private func visible(on day: Date) -> [CalendarItem] {
        let iso = CarliDate.isoDay(day)
        return (currentRange?.items ?? []).filter { $0.date == iso && isVisible($0) }
    }

    static func monday(of date: Date) -> Date {
        let calendar = CarliDate.calendar
        let day = calendar.startOfDay(for: date)
        let back = FrequencyDraft.isoWeekday(day) - 1
        return calendar.date(byAdding: .day, value: -back, to: day) ?? day
    }

    private func move(weeks step: Int) {
        guard let next = CarliDate.calendar.date(byAdding: .day, value: 7 * step, to: selected) else { return }
        withAnimation(.snappy) { selected = next }
    }

    private func load(force: Bool) async {
        let start = weekStart
        let key = CarliDate.isoDay(start)
        if !force, weeks[key] != nil { return }
        guard let end = CarliDate.calendar.date(byAdding: .day, value: 6, to: start) else { return }
        do {
            let envelope: DataEnvelope<CalendarRange> = try await api.get("v1/calendar", query: ["from": key, "to": CarliDate.isoDay(end)])
            weeks[key] = envelope.data
            failed = nil
        } catch {
            if weeks[key] == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }

    /// Accounts or calendars changed: every cached week is stale.
    private func reloadAll() async {
        weeks = [:]
        await load(force: true)
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

/// Title, time and detail of one calendar line. Google items carry their calendar's colour as a dot;
/// carli items show their module's symbol in ink.
private struct ItemLabel: View {
    var item: CalendarItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CarliSpace.s12) {
            marker
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(item.done || item.kind == .templates ? CarliColor.text2 : CarliColor.text)
                    .strikethrough(item.done && item.kind == .tasks)
                    .lineLimit(2)
                let detail = [item.timeRange, item.subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(item.meta?.overdue == true ? CarliColor.negative : CarliColor.text2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if item.meta?.important == true, !item.done {
                Image(systemName: "star.fill").font(.caption).foregroundStyle(CarliColor.text2)
                    .accessibilityLabel("Importante")
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var marker: some View {
        if item.kind == .google {
            Circle().fill(item.tint ?? CarliColor.text3).frame(width: 10, height: 10)
        } else if item.kind != .tasks {
            Image(systemName: item.kind?.symbol ?? "circle")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}

/// Month name, the seven days of the week and arrows; swiping sideways changes the week.
private struct WeekHeader: View {
    @Binding var selected: Date
    var days: [Date]
    var marks: Set<String>
    var move: (Int) -> Void

    var body: some View {
        VStack(spacing: CarliSpace.s8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(CarliColor.text)
                Spacer()
                Button("Semana anterior", systemImage: "chevron.left") { move(-1) }
                    .labelStyle(.iconOnly)
                Button("Semana siguiente", systemImage: "chevron.right") { move(1) }
                    .labelStyle(.iconOnly)
                    .padding(.leading, CarliSpace.s12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CarliColor.text2)
            .padding(.horizontal, CarliSpace.s12)

            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.vertical, CarliSpace.s4)
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            move(value.translation.width < 0 ? 1 : -1)
        })
    }

    private var title: String {
        let c = CarliDate.calendar.dateComponents([.month, .year], from: selected)
        let month = CarliDate.months[(c.month ?? 1) - 1].capitalizedFirst
        let thisYear = CarliDate.calendar.component(.year, from: .now)
        return c.year == thisYear ? month : "\(month) \(c.year ?? thisYear)"
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = CarliDate.calendar.isDate(day, inSameDayAs: selected)
        let isToday = CarliDate.calendar.isDateInToday(day)
        let marked = marks.contains(CarliDate.isoDay(day))
        return Button {
            withAnimation(.snappy) { selected = day }
        } label: {
            VStack(spacing: 2) {
                Text(TaskDates.weekdaysMondayFirst[FrequencyDraft.isoWeekday(day) - 1])
                    .font(.caption)
                    .foregroundStyle(isSelected ? CarliColor.onPrimary : CarliColor.text2)
                Text("\(CarliDate.calendar.component(.day, from: day))")
                    .font(.headline.weight(isToday ? .heavy : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? CarliColor.onPrimary : CarliColor.text)
                    .underline(isToday && !isSelected)
                Circle()
                    .fill(marked ? (isSelected ? CarliColor.onPrimary : CarliColor.text3) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CarliSpace.s8)
            .background(isSelected ? CarliColor.primary : .clear, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CarliDate.long(day))\(isToday ? ", hoy" : "")\(marked ? ", con cosas" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
