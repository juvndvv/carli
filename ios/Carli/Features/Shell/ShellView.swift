import SwiftUI

/// A module's own sections, picked from the title menu inside its tab.
struct ModuleSection: Identifiable, Hashable {
    var id: String
    var title: String
}

/// The modules that get a tab, in bar order, with their sections and "+" action.
enum ModuleTab: String, CaseIterable {
    case finance, tasks, notes, habits

    var title: String {
        switch self {
        case .finance: "Finanzas"
        case .tasks: "Tareas"
        case .notes: "Notas"
        case .habits: "Hábitos"
        }
    }

    /// Fluent UI Filled icons (MIT) in the asset catalog: soft, curved and filled.
    var icon: String { "tab-\(rawValue)" }

    var sections: [ModuleSection] {
        switch self {
        case .finance: [.init(id: "summary", title: "Resumen"), .init(id: "transactions", title: "Movimientos"),
                        .init(id: "budgets", title: "Presupuestos"), .init(id: "more", title: "Más")]
        case .tasks: [.init(id: "today", title: "Hoy"), .init(id: "upcoming", title: "Próximas"),
                      .init(id: "lists", title: "Listas"), .init(id: "templates", title: "Plantillas")]
        case .notes: [.init(id: "all", title: "Notas"), .init(id: "shopping", title: "Compra")]
        case .habits: [.init(id: "today", title: "Hoy"), .init(id: "list", title: "Hábitos"),
                       .init(id: "progress", title: "Progreso")]
        }
    }

    var addLabel: String {
        switch self {
        case .finance: "Nuevo movimiento"
        case .tasks: "Nueva tarea"
        case .notes: "Nueva nota"
        case .habits: "Nuevo hábito"
        }
    }
}

/// Signed-in root: a fixed system tab bar (Liquid Glass) with Inicio and one tab per
/// enabled module. Five tabs is the iPhone limit before "Más" overflow, so Buscar lives
/// in Inicio's toolbar instead of the search slot.
struct ShellView: View {
    @Environment(AuthModel.self) private var auth
    @State private var home: HomeModel?
    @State private var selection = "home"

    var body: some View {
        TabView(selection: $selection) {
            Tab("Inicio", image: "tab-home", value: "home") {
                if let home {
                    HomeView(model: home) { selection = $0 }
                }
            }

            ForEach(modules, id: \.self) { module in
                Tab(module.title, image: module.icon, value: module.rawValue) {
                    ModuleRootView(module: module) { selection = $0 }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onAppear {
            if home == nil { home = HomeModel(api: auth.api) }
        }
    }

    /// Enabled modules only; until /modules answers, Finanzas alone.
    private var modules: [ModuleTab] {
        guard let loaded = home?.modules else { return [.finance] }
        let on = Set(loaded.filter(\.isOn).map(\.id))
        return ModuleTab.allCases.filter { on.contains($0.rawValue) }
    }
}

/// A module tab: the header is a large "Resumen ⌄" selector (module name below) that
/// switches between sections; "+" sits top right. The system title menu only shows
/// with a centred inline title, so the selector is a toolbar Menu instead.
struct ModuleRootView: View {
    var module: ModuleTab
    /// Switches the tab bar to another module (Hoy in Tareas links to Hábitos).
    var openTab: (String) -> Void = { _ in }
    @Environment(AuthModel.self) private var auth
    @State private var section: ModuleSection
    @State private var adding = false
    @State private var toast: String?
    /// Filters a link asked for; entering Movimientos from the header menu starts clean.
    @State private var transactionFilters = TransactionFilters()
    @State private var path = NavigationPath()

    init(module: ModuleTab, openTab: @escaping (String) -> Void = { _ in }) {
        self.module = module
        self.openTab = openTab
        _section = State(initialValue: module.sections[0])
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { adding = true } label: {
                            // glassProminent picks its glyph colour from the tint; force the inverse of the ink fill.
                            Image(systemName: "plus")
                                .foregroundStyle(CarliColor.onPrimary)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(CarliColor.primary)
                        .accessibilityLabel(module.addLabel)
                    }
                }
                .sheet(isPresented: $adding) {
                    addSheet
                }
                .carliToast($toast)
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
        case (.finance, "more"):
            FinanceMoreView(api: auth.api, go: open)
        case (.tasks, "today"):
            TasksTodayView(api: auth.api) { openTab(ModuleTab.habits.rawValue) }
        case (.tasks, "upcoming"):
            TasksUpcomingView(api: auth.api)
        case (.tasks, "lists"):
            TaskListsView(api: auth.api)
        case (.tasks, "templates"):
            TemplatesView(api: auth.api)
        case (.habits, "today"):
            HabitsTodayView(api: auth.api) { adding = true }
        case (.habits, "list"):
            HabitsListView(api: auth.api) { adding = true }
        case (.habits, "progress"):
            HabitsProgressView(api: auth.api)
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
            TransactionSheet(model: TransactionFormModel(api: auth.api)) { toast = $0 }
        case .tasks:
            NewTaskSheet(api: auth.api, onSaved: { toast = $0 }) { seed in
                path.append(TemplateRoute(id: nil, seed: seed))
            }
        case .habits:
            HabitEditorView(api: auth.api) { id in path.append(HabitRoute(id: id)) }
        default:
            NavigationStack {
                PendingMigrationView(title: module.addLabel, symbol: "plus")
            }
            .presentationDetents([.medium, .large])
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
        if let target = module.sections.first(where: { $0.id == id }) { section = target }
    }

    private var sectionMenu: some View {
        Menu {
            Picker("Vista", selection: Binding(get: { section }, set: { picked in
                transactionFilters = TransactionFilters()
                path = NavigationPath()
                section = picked
            })) {
                ForEach(module.sections) { Text($0.title).tag($0) }
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
