import SwiftUI

enum HomeRoute: Hashable {
    case notifications, pending, settings, search
}

/// Inicio: greeting, then a card per module plus pending items and recent notifications.
struct HomeView: View {
    @Bindable var model: HomeModel
    var openModule: (String) -> Void

    @Environment(AuthModel.self) private var auth

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CarliSpace.s16) {
                    let hasNotifications = !(model.notifications.value ?? []).isEmpty
                    if hasNotifications { NotificationsCard(model: model) }
                    PendingCard(summary: model.pending)
                    FinanceCard(model: model) { openModule(AppModule.finance) }
                    if model.isEnabled(AppModule.tasks) {
                        TasksCard(model: model) { openModule(AppModule.tasks) }
                    }
                    if model.isEnabled(AppModule.habits), let habits = model.habits, !habits.habits.isEmpty {
                        HabitsCard(model: model, habits: habits) { openModule(AppModule.habits) }
                    }
                    if model.isEnabled(AppModule.notes), let notes = model.notes {
                        NotesCard(model: model, snapshot: notes) { openModule(AppModule.notes) }
                    }
                    if !hasNotifications { NotificationsCard(model: model) }
                }
                .padding(.horizontal, CarliSpace.s16)
                .padding(.bottom, CarliSpace.s32)
            }
            .background(CarliColor.bg)
            .navigationTitle(title)
            .navigationSubtitle(CarliDate.long(.now))
            .toolbar { toolbar }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .notifications: PendingMigrationView(title: "Notificaciones")
                case .pending: PendingMigrationView(title: "Pendientes")
                case .settings: SettingsStubView()
                case .search: PendingMigrationView(title: "Buscar", symbol: "magnifyingglass")
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .onHabitsChanged { await model.loadHabits() }
            .onTasksChanged { await model.loadTasks() }
            .onReceive(NotificationCenter.default.publisher(for: .notesChanged)) { _ in Task { await model.loadNotes() } }
        }
        .habitActions(model.habitActions)
        .carliToast($model.toast)
    }

    private var title: String {
        let greeting = CarliDate.greeting(.now)
        guard let name = auth.user?.firstName, !name.isEmpty else { return greeting }
        return "\(greeting), \(name)"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
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

    var body: some View {
        CarliCard(padding: 0) {
            CardHeader(title: "Notificaciones recientes") {
                NavigationLink("Ver todas", value: HomeRoute.notifications)
                    .font(.subheadline.weight(.medium))
            }
            .padding(CarliSpace.s16)

            switch model.notifications {
            case .loading:
                VStack(alignment: .leading, spacing: CarliSpace.s8) {
                    SkeletonBar(width: 200, height: 14)
                    SkeletonBar(width: 140)
                }
                .padding([.horizontal, .bottom], CarliSpace.s16)
            case .failed:
                message("No se han podido cargar las notificaciones.")
            case .loaded(let items) where items.isEmpty:
                message("No tienes notificaciones recientes.")
            case .loaded(let items):
                ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 34) }
                    NotificationRow(item: item)
                }
                .padding(.bottom, CarliSpace.s4)
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(CarliColor.text3)
            .frame(maxWidth: .infinity)
            .padding([.horizontal, .bottom], CarliSpace.s16)
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
                    NavigationLink("Revisar", value: HomeRoute.pending)
                        .font(.subheadline.weight(.medium))
                }
                .padding(CarliSpace.s16)
                ForEach(summary.byModule) { entry in
                    let described = PendingType.describe(entry)
                    NavigationLink(value: HomeRoute.pending) {
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

private struct TasksCard: View {
    var model: HomeModel
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

            if let view = model.tasks.value {
                let first = Array((view.overdue + view.today).prefix(3))
                if !first.isEmpty {
                    Divider()
                    ForEach(first) { task in
                        TaskLine(task: task) { Task { await model.complete(task) } }
                    }
                    .padding(.bottom, CarliSpace.s4)
                }
            }
        }
    }

    private var subtitle: String? {
        switch model.tasks {
        case .loaded(let view): view.headline
        case .failed: "No se han podido cargar"
        case .loading: " "
        }
    }
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

private struct NotesCard: View {
    var model: HomeModel
    var snapshot: NotesSnapshot
    var open: () -> Void

    var body: some View {
        let shopping = snapshot.primaryShopping
        let pinned = Array(snapshot.pinned.filter { $0.id != shopping?.id }.prefix(2))
        if shopping != nil || !pinned.isEmpty {
            CarliCard {
                if let shopping {
                    Button(action: open) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notas · \(shopping.displayTitle)")
                                    .font(.footnote)
                                    .foregroundStyle(CarliColor.text2)
                                Text("\(Text("\(shopping.openCount)").font(.title.weight(.semibold)).foregroundStyle(CarliColor.text)) \(Text("por comprar").font(.body).foregroundStyle(CarliColor.text2))")
                                    .monospacedDigit()
                            }
                            Spacer()
                            Chevron().padding(.bottom, CarliSpace.s8)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Abrir la lista de la compra")

                    let open = shopping.items.filter { !$0.checked }.sorted { $0.position < $1.position }.prefix(3)
                    ForEach(Array(open)) { item in
                        Button { Task { await model.check(item) } } label: {
                            HStack(spacing: CarliSpace.s12) {
                                Image(systemName: "circle")
                                    .font(.title3)
                                    .foregroundStyle(CarliColor.text3)
                                Text(item.text)
                                    .font(.body)
                                    .foregroundStyle(CarliColor.text)
                                Spacer(minLength: 0)
                                if let quantity = item.quantity, !quantity.isEmpty {
                                    Text(quantity).font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                            }
                            .padding(.vertical, CarliSpace.s8)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Al carro")
                    }
                    .padding(.top, CarliSpace.s8)
                }
                if !pinned.isEmpty {
                    if shopping != nil { Divider().padding(.vertical, CarliSpace.s12) }
                    HStack(spacing: CarliSpace.s8) {
                        ForEach(pinned) { note in
                            Button(action: open) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fijada")
                                        .font(.footnote)
                                        .foregroundStyle(CarliColor.text2)
                                    Text(note.displayTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(CarliColor.text)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, CarliSpace.s12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CarliColor.surface2, in: .rect(cornerRadius: CarliRadius.control, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        if pinned.count == 1 { Spacer().frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }
}

/// Temporary Ajustes until that screen is migrated: who is signed in and a way out.
private struct SettingsStubView: View {
    @Environment(AuthModel.self) private var auth

    var body: some View {
        List {
            if let user = auth.user {
                Section {
                    LabeledContent("Nombre", value: user.name)
                    LabeledContent("Email", value: user.email)
                }
            }
            Section {
                Button("Cerrar sesión", role: .destructive) {
                    Task { await auth.logout() }
                }
            } footer: {
                Text("El resto de Ajustes llega cuando migremos esa pantalla.")
            }
        }
        .navigationTitle("Ajustes")
    }
}
