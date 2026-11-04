import SwiftUI

enum HomeRoute: Hashable {
    case notifications, settings, search, calendar
    case pending(module: String? = nil, type: String? = nil)
}

/// Inicio: greeting, then a card per module plus pending items and recent notifications.
/// A card with nothing to show is left out.
struct HomeView: View {
    @Bindable var model: HomeModel
    var openModule: (String) -> Void

    @Environment(AuthModel.self) private var auth
    @Environment(AppRouter.self) private var router
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            cards
                .navigationTitle("Inicio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(removing: .title)
                .toolbar { toolbar }
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .notifications: NotificationsView(model: NotificationsModel(api: auth.api))
                    case .pending(let module, let type): PendingView(model: PendingModel(api: auth.api, module: module, type: type))
                    case .settings: SettingsView(modules: model.modules)
                    case .search: SearchView(api: auth.api, enabledModules: Set((model.modules ?? []).filter(\.isOn).map(\.id) + [AppModule.finance]))
                    case .calendar:
                        CalendarView(api: auth.api)
                            .navigationTitle("Calendario")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
                .settingsDestinations(api: auth.api, modules: model.modules)
                .tasksDestinations(api: auth.api)
                .navigationDestination(for: WhoopRoute.self) { _ in WhoopView(api: auth.api) }
        }
        .onChange(of: router.request?.id) {
            // Leaving Inicio for another tab (search, settings shortcuts) closes what was pushed here.
            if let tab = router.request?.tab, tab != "home" { path = NavigationPath() }
        }
        .onChange(of: router.pending?.id, initial: true) {
            guard let link = router.take(for: "home") else { return }
            var next = NavigationPath()
            for step in link.steps {
                switch step {
                case .home(let route): next.append(route)
                case .settings(let page): next.append(page)
                default: break
                }
            }
            path = next
        }
        .habitActions(model.habitActions)
        .carliToast($model.toast)
    }

    /// A card per module plus pending items and recent notifications; empty ones are hidden.
    private var cards: some View {
            ScrollView {
                LazyVStack(spacing: CarliSpace.s16) {
                    if let items = model.notifications.value, !items.isEmpty { NotificationsCard(model: model, items: items) }
                    PendingCard(summary: model.pending)
                    if model.isEnabled(AppModule.health), let whoop = model.whoop, whoop.configured, whoop.account != nil {
                        WhoopTodayCard(status: whoop, day: model.whoopDay)
                    }
                    FinanceCard(model: model) { openModule(AppModule.finance) }
                    if model.isEnabled(AppModule.calendar), let agenda = model.agenda, agenda.google.accounts > 0, !AgendaCard.upcoming(in: agenda).isEmpty {
                        AgendaCard(agenda: agenda)
                    }
                    if model.isEnabled(AppModule.tasks), let tasks = model.tasks.value, !(tasks.overdue + tasks.today).isEmpty {
                        TasksCard(model: model, view: tasks) { openModule(AppModule.tasks) }
                    }
                    if model.isEnabled(AppModule.habits), let habits = model.habits, habits.summary.total > 0 {
                        HabitsCard(model: model, habits: habits) { _ = router.open(url: "/habitos/hoy") }
                    }
                }
                .padding(.horizontal, CarliSpace.s16)
                .padding(.bottom, CarliSpace.s32)
            }
            .background(CarliColor.bg)
            .refreshable { await model.load() }
            .task { await model.load() }
            .onHabitsChanged { await model.loadHabits() }
            .onHealthChanged { await model.loadWhoop() }
            .onTasksChanged { await model.loadTasks() }
            .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in Task { await model.loadAgenda() } }
            .onReceive(NotificationCenter.default.publisher(for: .notificationsChanged)) { _ in Task { await model.loadNotifications() } }
            .onReceive(NotificationCenter.default.publisher(for: .pendingChanged)) { _ in Task { await model.loadPending() } }
            .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in
                Task {
                    await model.loadFinance()
                    await model.loadPending()
                }
            }
    }

    private var greeting: String {
        let greeting = CarliDate.greeting(.now)
        guard let name = auth.user?.firstName, !name.isEmpty else { return greeting }
        return "\(greeting), \(name)"
    }

    /// "Inicio" and today's date, without a section menu.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inicio")
                .font(.title2.weight(.bold))
            Text(CarliDate.long(.now))
                .font(.caption)
                .foregroundStyle(CarliColor.text2)
                .lineLimit(1)
        }
        .foregroundStyle(CarliColor.text)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). Inicio")
        .accessibilityAddTraits(.isHeader)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            header
        }
        .sharedBackgroundVisibility(.hidden)
        if model.isEnabled(AppModule.calendar) {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HomeRoute.calendar) {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Calendario")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: HomeRoute.search) {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Buscar")
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: HomeRoute.notifications) {
                Image(systemName: "bell")
            }
            .badge(model.unreadCount)
            .accessibilityLabel(model.unreadCount > 0 ? "Notificaciones (\(model.unreadCount) sin leer)" : "Notificaciones")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: HomeRoute.settings) {
                Text(String(auth.user?.firstName.prefix(1) ?? "·").uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CarliColor.onPrimary)
                    .frame(width: 30, height: 30)
                    .background(CarliColor.primary, in: .circle)
            }
            .accessibilityLabel("Ajustes")
        }
    }
}

// MARK: Cards

private struct NotificationsCard: View {
    var model: HomeModel
    var items: [AppNotification]
    @Environment(AppRouter.self) private var router

    var body: some View {
        CarliCard(padding: 0) {
            CardHeader(title: "Notificaciones recientes") {
                NavigationLink("Ver todas", value: HomeRoute.notifications)
                    .font(.subheadline.weight(.medium))
            }
            .padding(CarliSpace.s16)

            ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, 34) }
                Button {
                    if item.unread { Task { await model.markRead(item) } }
                    router.open(url: item.url)
                } label: {
                    NotificationRow(item: item).contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, CarliSpace.s4)
        }
    }
}

private struct NotificationRow: View {
    var item: AppNotification

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CarliSpace.s12) {
            Circle()
                .fill(item.unread ? CarliColor.primary : .clear)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(item.unread ? .semibold : .regular))
                    .foregroundStyle(CarliColor.text)
                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if let created = item.createdAt.flatMap(CarliDate.instant) {
                Text(CarliDate.relative(created))
                    .font(.caption)
                    .foregroundStyle(CarliColor.text3)
            }
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.unread ? "Sin leer" : "")
    }
}

private struct PendingCard: View {
    var summary: PendingSummary?

    var body: some View {
        if let summary, summary.total > 0 {
            CarliCard(padding: 0) {
                CardHeader(title: "Pendientes",
                           subtitle: summary.total == 1 ? "1 elemento por revisar" : "\(summary.total) elementos por revisar") {
                    NavigationLink("Revisar", value: HomeRoute.pending())
                        .font(.subheadline.weight(.medium))
                }
                .padding(CarliSpace.s16)
                ForEach(summary.byModule) { entry in
                    let described = PendingType.describe(entry)
                    NavigationLink(value: HomeRoute.pending(module: entry.module, type: entry.type)) {
                        HStack(spacing: CarliSpace.s12) {
                            Image(systemName: described.symbol)
                                .foregroundStyle(CarliColor.text2)
                                .frame(width: 24)
                            Text(described.label)
                                .font(.subheadline)
                                .foregroundStyle(CarliColor.text)
                            Spacer(minLength: 0)
                            Chevron()
                        }
                        .padding(.horizontal, CarliSpace.s16)
                        .padding(.vertical, 12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, CarliSpace.s4)
            }
        }
    }
}

private struct FinanceCard: View {
    var model: HomeModel
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            CarliCard {
                CardHeader(title: "Finanzas", symbol: "creditcard") { Chevron() }
                    .padding(.bottom, CarliSpace.s12)
                switch model.finance {
                case .loading:
                    VStack(alignment: .leading, spacing: CarliSpace.s8) {
                        SkeletonBar(width: 110)
                        SkeletonBar(width: 200, height: 34)
                        SkeletonBar(width: 160, height: 14)
                    }
                case .failed:
                    Text("No se ha podido cargar el resumen de Finanzas.")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                case .loaded(let summary):
                    summaryView(summary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abrir Finanzas")
    }

    private func summaryView(_ data: FinanceSummary) -> some View {
        VStack(alignment: .leading, spacing: CarliSpace.s4) {
            Text("Patrimonio neto")
                .font(.caption.weight(.medium))
                .foregroundStyle(CarliColor.text2)
            Text(Money.format(data.netWorthCents))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(CarliColor.text)
                .contentTransition(.numericText())
            Text("Gastado en \(data.period.shortName ?? data.period.name): \(Text(Money.format(data.spentCents)).fontWeight(.semibold).foregroundStyle(CarliColor.text))")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(CarliColor.text2)
            Text("\(data.period.name) · \(Plural.daysLeft(data.period.daysRemaining ?? 0))")
                .font(.footnote)
                .foregroundStyle(CarliColor.text3)
        }
    }
}

/// Today's Google events still to come; tasks keep their own card.
private struct AgendaCard: View {
    var agenda: CalendarRange

    var body: some View {
        CarliCard(padding: 0) {
            NavigationLink(value: HomeRoute.calendar) {
                VStack(alignment: .leading, spacing: 0) {
                    CardHeader(title: "Agenda", subtitle: subtitle, symbol: "calendar") { Chevron() }
                        .padding(CarliSpace.s16)
                    if !upcoming.isEmpty {
                        Divider()
                        ForEach(upcoming.prefix(3), id: \.key) { item in
                            HStack(spacing: CarliSpace.s12) {
                                Circle().fill(item.tint ?? CarliColor.text3).frame(width: 8, height: 8)
                                Text(item.title)
                                    .foregroundStyle(CarliColor.text)
                                    .lineLimit(1)
                                Spacer(minLength: CarliSpace.s8)
                                Text(item.time ?? "Todo el día")
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(CarliColor.text2)
                            }
                            .padding(.horizontal, CarliSpace.s16)
                            .padding(.vertical, CarliSpace.s12)
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abrir el calendario")
        }
    }

    private var upcoming: [CalendarItem] { Self.upcoming(in: agenda) }

    /// Google events of today that have not ended yet, all-day ones first.
    static func upcoming(in agenda: CalendarRange) -> [CalendarItem] {
        let now = CarliDate.calendar.dateComponents([.hour, .minute], from: .now)
        let clock = String(format: "%02d:%02d", now.hour ?? 0, now.minute ?? 0)
        return agenda.items.filter { item in
            guard item.kind == .google else { return false }
            guard let time = item.time else { return true }
            return (item.endTime ?? time) >= clock || (item.endTime ?? "") < time
        }
    }

    private var subtitle: String {
        switch upcoming.count {
        case 1: "1 evento más hoy"
        default: "\(upcoming.count) eventos más hoy"
        }
    }
}

private struct TasksCard: View {
    var model: HomeModel
    var view: TasksToday
    var open: () -> Void

    var body: some View {
        CarliCard(padding: 0) {
            Button(action: open) {
                CardHeader(title: "Tareas", subtitle: subtitle, symbol: "checkmark.circle") { Chevron() }
                    .padding(CarliSpace.s16)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abrir Tareas")

            Divider()
            ForEach(Array((view.overdue + view.today).prefix(3))) { task in
                TaskLine(task: task) { Task { await model.complete(task) } }
            }
            .padding(.bottom, CarliSpace.s4)
        }
    }

    private var subtitle: String { view.headline }
}

private struct TaskLine: View {
    var task: TaskItem
    var complete: () -> Void

    var body: some View {
        HStack(spacing: CarliSpace.s4) {
            Button(action: complete) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? CarliColor.primary : CarliColor.text3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Marcar \(task.title) como hecha")
            .sensoryFeedback(.success, trigger: task.isDone)

            Text(task.title)
                .font(.body)
                .foregroundStyle(CarliColor.text)
                .lineLimit(1)
            Spacer(minLength: CarliSpace.s8)
            if task.overdue == true, let due = task.dueDate.flatMap(CarliDate.day) {
                Text(CarliDate.short(due))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CarliColor.negative)
            } else if let time = task.dueTime {
                Text(String(time.prefix(5)))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(CarliColor.text2)
            }
        }
        .padding(.leading, CarliSpace.s4)
        .padding(.trailing, CarliSpace.s16)
    }
}

private struct HabitsCard: View {
    var model: HomeModel
    var habits: HabitsToday
    var open: () -> Void

    var body: some View {
        CarliCard {
            Button(action: open) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hábitos")
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text2)
                        Text(headline)
                            .font(.title.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(CarliColor.text)
                    }
                    Spacer()
                    Chevron()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abrir Hábitos")

            if !habits.pending.isEmpty {
                HabitRingStrip(habits: habits.pending, actions: model.habitActions)
                    .padding(.top, CarliSpace.s12)
            }
        }
    }

    private var headline: String {
        let s = habits.summary
        if s.total == 0 { return "Nada que hacer hoy" }
        return habits.pending.isEmpty ? "Todo hecho · \(s.done) de \(s.total)" : "\(s.done) de \(s.total)"
    }
}
