import SwiftUI

/// A module's own sections, picked from the title menu inside its tab.
struct ModuleSection: Identifiable, Hashable {
    var id: String
    var title: String
}

/// The modules that get a tab, in bar order, with their sections and "+" action.
enum ModuleTab: String, CaseIterable {
    case finance, tasks, notes, health

    var title: String {
        switch self {
        case .finance: "Finanzas"
        case .tasks: "Tareas"
        case .notes: "Notas"
        case .health: "Salud"
        }
    }

    /// Fluent UI Filled icons (MIT) in the asset catalog: soft, curved and filled.
    var icon: String { "tab-\(rawValue)" }

    var sections: [ModuleSection] {
        switch self {
        case .finance: [.init(id: "summary", title: "Resumen"), .init(id: "transactions", title: "Movimientos"),
                        .init(id: "budgets", title: "Presupuestos")]
            + FinanceMorePage.allCases.map { .init(id: $0.rawValue, title: $0.sectionTitle) }
        case .tasks: [.init(id: "today", title: "Hoy"), .init(id: "upcoming", title: "Próximas"),
                      .init(id: "lists", title: "Listas"), .init(id: "templates", title: "Plantillas")]
        case .notes: [.init(id: "all", title: "Notas"), .init(id: "shopping", title: "Compra")]
        case .health: Self.weightSections + Self.habitSections
        }
    }

    /// Salud holds the weight and the Hábitos module; each half shows only while its module is on.
    static let weightSections: [ModuleSection] = [.init(id: "summary", title: "Resumen"), .init(id: "measurements", title: "Mediciones"),
                                                  .init(id: "trends", title: "Tendencias")]
    static let habitSections: [ModuleSection] = [.init(id: "habits-today", title: "Hábitos hoy"), .init(id: "habits", title: "Hábitos"),
                                                 .init(id: "habits-progress", title: "Progreso")]

    func sections(enabled: Set<String>) -> [ModuleSection] {
        guard self == .health else { return sections }
        let weight = enabled.contains(AppModule.health) ? Self.weightSections : []
        let habits = enabled.contains(AppModule.habits) ? Self.habitSections : []
        return weight + habits
    }

    /// The modules that make this tab show up.
    var moduleIds: [String] {
        self == .health ? [AppModule.health, AppModule.habits] : [rawValue]
    }

    var addLabel: String {
        switch self {
        case .finance: "Nuevo movimiento"
        case .tasks: "Nueva tarea"
        case .notes: "Nueva nota"
        case .health: "Pesarse"
        }
    }
}

/// Signed-in root: a fixed system tab bar (Liquid Glass) with Inicio and one tab per
/// enabled module. Five tabs is the iPhone limit before "Más" overflow, so Buscar lives
/// in Inicio's toolbar instead of the search slot.
struct ShellView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var home: HomeModel?
    @State private var selection = "home"
    @State private var router = AppRouter()
    @State private var push = PushManager.shared

    var body: some View {
        TabView(selection: $selection) {
            Tab("Inicio", image: "tab-home", value: "home") {
                if let home {
                    HomeView(model: home) { selection = $0 }
                }
            }

            ForEach(modules, id: \.self) { module in
                Tab(module.title, image: module.icon, value: module.rawValue) {
                    let sections = module.sections(enabled: enabledIds)
                    ModuleRootView(module: module, sections: sections) { selection = $0 }
                        .id(sections)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(router)
        .onAppear {
            if home == nil { home = HomeModel(api: auth.api) }
        }
        .onChange(of: router.request?.id) { route() }
        .onChange(of: home?.modules) { route() }
        .onChange(of: push.opened?.id, initial: true) { openExternal() }
        .onReceive(NotificationCenter.default.publisher(for: .modulesChanged)) { _ in
            Task { await home?.loadModules() }
        }
        .task(id: scenePhase) {
            // Keeps Inicio's pending count and unread badge fresh while the app is open.
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { return }
                await home?.loadPending()
                await home?.loadNotifications()
            }
        }
    }

    /// Switches to the tab a link targets; links to modules that are off are dropped.
    private func route() {
        guard let tab = router.request?.tab else { return }
        if tab == "home" || modules.map(\.rawValue).contains(tab) {
            selection = tab
            router.settle()
        } else if home?.modules != nil {
            router.drop()
            router.settle()
            selection = "home"
        }
    }

    /// A push tap or quick action: marks the notification read and opens its route (the inbox when unknown).
    private func openExternal() {
        guard let opened = push.opened else { return }
        push.opened = nil
        if let id = opened.notificationId {
            Task {
                let _: UnreadCount? = try? await auth.api.post("v1/notifications/read", body: Patch(["ids": .array([.string(id)])]))
                NotificationCenter.default.post(name: .notificationsChanged, object: nil)
            }
        }
        router.open(url: opened.url, fallback: .home(.home(.notifications)))
    }

    /// Enabled modules only; until /modules answers, Finanzas alone.
    private var modules: [ModuleTab] {
        guard home?.modules != nil else { return [.finance] }
        let on = enabledIds
        return ModuleTab.allCases.filter { !on.isDisjoint(with: $0.moduleIds) }
    }

    private var enabledIds: Set<String> {
        Set((home?.modules ?? []).filter(\.isOn).map(\.id))
    }
}

/// A module tab: the header is a large "Resumen ⌄" selector (module name below) that
/// switches between sections; "+" sits top right. The system title menu only shows
/// with a centred inline title, so the selector is a toolbar Menu instead.
struct ModuleRootView: View {
    var module: ModuleTab
    var sections: [ModuleSection]
    /// Switches the tab bar to another module (Hoy in Tareas links to Hábitos).
    var openTab: (String) -> Void = { _ in }
    @Environment(AuthModel.self) private var auth
    @Environment(AppRouter.self) private var router
    @State private var section: ModuleSection
    @State private var adding = false
    @State private var weighing = false
    @State private var newKind: TransactionFormModel.Kind = .expense
    @State private var toast: String?
    /// Filters a link asked for; entering Movimientos from the header menu starts clean.
    @State private var transactionFilters = TransactionFilters()
    @State private var path = NavigationPath()
    /// Notas and Compra share one snapshot and write queue.
    @State private var notesStore: NotesStore?
    @State private var shoppingList: String?
    @State private var shoppingFocus = 0

    init(module: ModuleTab, sections: [ModuleSection]? = nil, openTab: @escaping (String) -> Void = { _ in }) {
        let sections = sections.flatMap { $0.isEmpty ? nil : $0 } ?? module.sections
        self.module = module
        self.sections = sections
        self.openTab = openTab
        _section = State(initialValue: sections[0])
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(section.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(removing: .title)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        sectionMenu
                    }
                    .sharedBackgroundVisibility(.hidden)
                    // Finanzas' admin pages bring their own create button.
                    if !isFinancePage {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: add) {
                                // glassProminent picks its glyph colour from the tint; force the inverse of the ink fill.
                                Image(systemName: "plus")
                                    .foregroundStyle(CarliColor.onPrimary)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(CarliColor.primary)
                            .accessibilityLabel(addLabel)
                        }
                    }
                }
                .sheet(isPresented: $adding) {
                    addSheet
                }
                .sheet(isPresented: $weighing) {
                    WeighInSheet(api: auth.api) { toast = $0 }
                }
                .carliToast($toast)
        }
        .onChange(of: router.pending?.id, initial: true) { applyLink() }
    }

    /// Opens a link addressed to this tab: its section, Movimientos filters, pushed screens and sheets.
    private func applyLink() {
        guard let link = router.take(for: module.rawValue) else { return }
        if module == .notes, notesStore == nil { notesStore = NotesStore(api: auth.api) }
        transactionFilters = link.filters ?? TransactionFilters()
        if let id = link.section, let target = sections.first(where: { $0.id == id }) { section = target }
        path = NavigationPath()
        let steps = link.steps
        if !steps.isEmpty {
            // One runloop later, so the new section's destinations are registered before pushing.
            Task { @MainActor in
                await Task.yield()
                steps.forEach(push)
            }
        }
        if let kind = link.newTransaction, module == .finance {
            newKind = kind
            adding = true
        }
        if link.weighIn, module == .health {
            weighing = true
        }
    }

    private func push(_ step: AppLinkStep) {
        switch step {
        case .financePage(let page): path.append(page)
        case .account(let id): path.append(AccountLink(id: id))
        case .goal(let id): path.append(GoalRoute(id: id))
        case .contact(let id): path.append(ContactRoute(id: id))
        case .banks: path.append(BanksRoute())
        case .bankLink(let id, let renewed): path.append(BankLinkRoute(connectionId: id, renewed: renewed))
        case .task(let id): path.append(TaskRoute(id: id))
        case .taskList(let id): path.append(TaskListRoute(id: id))
        case .template(let id): path.append(TemplateRoute(id: id))
        case .tasksSettings: path.append(TasksSettingsRoute())
        case .habit(let id): path.append(HabitRoute(id: id))
        case .habitsSettings: path.append(HabitsSettingsRoute())
        case .measurement(let id): path.append(MeasurementRoute(id: id))
        case .healthSettings: path.append(HealthSettingsRoute())
        case .note(let id): path.append(NoteRoute(id: id))
        case .folder(let id): path.append(FolderRoute(id: id))
        case .notesCollection(let trash): path.append(NotesCollectionRoute(trash: trash))
        case .notesSettings: path.append(NotesSettingsRoute())
        case .home, .settings: break
        }
    }

    @ViewBuilder
    private var content: some View {
        switch (module, section.id) {
        case (.finance, "summary"):
            FinanceSummaryView(model: FinanceSummaryModel(api: auth.api), go: open)
        case (.finance, "budgets"):
            BudgetsView(model: BudgetsModel(api: auth.api), go: open)
        case (.finance, "transactions"):
            TransactionsView(model: TransactionsModel(api: auth.api, filters: transactionFilters))
                .id(transactionFilters)
        case (.finance, let id) where FinanceMorePage(rawValue: id) != nil:
            FinancePageView(page: FinanceMorePage(rawValue: id)!, api: auth.api, go: open)
        case (.tasks, "today"):
            TasksTodayView(api: auth.api) { _ = router.open(url: "/habitos/hoy") }
        case (.tasks, "upcoming"):
            TasksUpcomingView(api: auth.api)
        case (.tasks, "lists"):
            TaskListsView(api: auth.api)
        case (.tasks, "templates"):
            TemplatesView(api: auth.api)
        case (.health, "summary"):
            HealthSummaryView(api: auth.api, habitsOn: sections.contains(ModuleTab.habitSections[0])) { weighing = true }
        case (.health, "measurements"):
            MeasurementsView(api: auth.api)
        case (.health, "trends"):
            HealthTrendsView(api: auth.api)
        case (.health, "habits-today"):
            HabitsTodayView(api: auth.api) { adding = true }
        case (.health, "habits"):
            HabitsListView(api: auth.api) { adding = true }
        case (.health, "habits-progress"):
            HabitsProgressView(api: auth.api)
        case (.notes, "all"):
            if let notesStore {
                NotesHomeView(store: notesStore) { adding = true }
            } else {
                ProgressView().onAppear { notesStore = NotesStore(api: auth.api) }
            }
        case (.notes, "shopping"):
            if let notesStore {
                ShoppingSectionView(store: notesStore, selected: $shoppingList, focusRequest: shoppingFocus)
            } else {
                ProgressView().onAppear { notesStore = NotesStore(api: auth.api) }
            }
        default:
            ScrollView {
                ContentUnavailableView {
                    Label(section.title, systemImage: "hammer")
                } description: {
                    Text("Esta sección de \(module.title) todavía no está migrada a la app nativa.")
                }
                .padding(.top, CarliSpace.s48)
                .padding(.horizontal, CarliSpace.s16)
            }
            .background(CarliColor.bg)
        }
    }

    @ViewBuilder
    private var addSheet: some View {
        switch module {
        case .finance:
            TransactionSheet(model: TransactionFormModel(api: auth.api, kind: newKind)) { toast = $0 }
        case .tasks:
            NewTaskSheet(api: auth.api, onSaved: { toast = $0 }) { seed in
                path.append(TemplateRoute(id: nil, seed: seed))
            }
        case .health:
            HabitEditorView(api: auth.api) { id in path.append(HabitRoute(id: id)) }
        case .notes:
            NewNoteSheet { type in
                if let notesStore { path.append(NoteRoute(id: notesStore.createNote(type), fresh: true)) }
            }
        default:
            NavigationStack {
                PendingMigrationView(title: module.addLabel, symbol: "plus")
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// "+" opens the module's create sheet; in Compra it focuses the add-product field instead,
    /// and in Salud's weight sections it opens "Pesarse".
    private func add() {
        if module == .notes && section.id == "shopping" {
            shoppingFocus += 1
        } else if isWeightSection {
            weighing = true
        } else {
            newKind = .expense
            adding = true
        }
    }

    private func open(_ route: FinanceRoute) {
        switch route {
        case .budgets:
            show("budgets")
        case .transactions(let filters):
            transactionFilters = filters
            show("transactions")
        }
    }

    private func show(_ id: String) {
        path = NavigationPath()
        if let target = sections.first(where: { $0.id == id }) { section = target }
    }

    private var isFinancePage: Bool {
        module == .finance && FinanceMorePage(rawValue: section.id) != nil
    }

    private var isWeightSection: Bool {
        module == .health && ModuleTab.weightSections.contains(section)
    }

    private var addLabel: String {
        if module == .notes && section.id == "shopping" { return "Añadir producto" }
        if module == .health && !isWeightSection { return "Nuevo hábito" }
        return module.addLabel
    }

    private var sectionMenu: some View {
        Menu {
            Picker("Vista", selection: Binding(get: { section }, set: { picked in
                transactionFilters = TransactionFilters()
                path = NavigationPath()
                section = picked
            })) {
                ForEach(sections) { Text($0.title).tag($0) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(section.title)
                        .font(.title2.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(CarliColor.text2)
                }
                Text(module.title)
                    .font(.caption)
                    .foregroundStyle(CarliColor.text2)
            }
            .foregroundStyle(CarliColor.text)
            .fixedSize()
        }
        .accessibilityLabel("\(module.title), vista \(section.title)")
        .accessibilityHint("Cambiar de vista")
    }
}
