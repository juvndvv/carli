import SwiftUI

/// One tab in the contextual bar.
struct ShellTab: Identifiable, Hashable {
    var id: String
    var title: String
    var symbol: String
}

/// Which tabs the bar shows: Inicio lists the modules; inside a module, its own screens.
enum ShellSection: String {
    case home, finance, tasks, notes, habits

    var tabs: [ShellTab] {
        switch self {
        case .home: []
        case .finance: [
            ShellTab(id: "finance.summary", title: "Resumen", symbol: "square.grid.2x2"),
            ShellTab(id: "finance.transactions", title: "Movimientos", symbol: "list.bullet"),
            ShellTab(id: "finance.budgets", title: "Presupuestos", symbol: "gauge.with.dots.needle.50percent"),
            ShellTab(id: "finance.more", title: "Más", symbol: "line.3.horizontal"),
        ]
        case .tasks: [
            ShellTab(id: "tasks.today", title: "Hoy", symbol: "checkmark.circle"),
            ShellTab(id: "tasks.upcoming", title: "Próximas", symbol: "calendar"),
            ShellTab(id: "tasks.lists", title: "Listas", symbol: "list.bullet"),
            ShellTab(id: "tasks.templates", title: "Plantillas", symbol: "repeat"),
        ]
        case .notes: [
            ShellTab(id: "notes.all", title: "Notas", symbol: "note.text"),
            ShellTab(id: "notes.shopping", title: "Compra", symbol: "cart"),
        ]
        case .habits: [
            ShellTab(id: "habits.today", title: "Hoy", symbol: "target"),
            ShellTab(id: "habits.list", title: "Hábitos", symbol: "list.bullet"),
            ShellTab(id: "habits.progress", title: "Progreso", symbol: "chart.bar"),
        ]
        }
    }

    var addLabel: String {
        switch self {
        case .tasks: "Nueva tarea"
        case .notes: "Nueva nota"
        case .habits: "Nuevo hábito"
        default: "Nuevo movimiento"
        }
    }
}

/// Signed-in root: the system tab bar (Liquid Glass) with Inicio pinned first. The
/// trailing search-role slot holds Buscar on Inicio and "+" inside a module.
struct ShellView: View {
    @Environment(AuthModel.self) private var auth
    @State private var home: HomeModel?
    @State private var section = ShellSection.home
    @State private var selection = "home"
    @State private var adding = false

    private static let search = "search", add = "add"

    var body: some View {
        TabView(selection: Binding(get: { selection }, set: select)) {
            Tab("Inicio", systemImage: "house", value: "home") {
                if let home {
                    HomeView(model: home, openModule: open)
                }
            }

            ForEach(barTabs) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab.id) {
                    NavigationStack {
                        PendingMigrationView(title: tab.title, symbol: tab.symbol)
                    }
                }
            }

            if section == .home {
                Tab("Buscar", systemImage: "magnifyingglass", value: Self.search, role: .search) {
                    NavigationStack {
                        PendingMigrationView(title: "Buscar", symbol: "magnifyingglass")
                    }
                }
            } else {
                Tab(section.addLabel, systemImage: "plus", value: Self.add, role: .search) {
                    Color.clear
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $adding) {
            NavigationStack {
                PendingMigrationView(title: section.addLabel, symbol: "plus")
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if home == nil { home = HomeModel(api: auth.api) }
        }
    }

    /// Inicio lists the enabled modules; coming-soon modules stay out of the bar.
    private var barTabs: [ShellTab] {
        guard section == .home else { return section.tabs }
        let modules = home?.modules?.filter(\.isOn)
            ?? [AppModule(id: AppModule.finance, name: "Finanzas", icon: "wallet")]
        return modules.map { ShellTab(id: "module.\($0.id)", title: $0.name, symbol: CarliIcon.symbol($0.icon)) }
    }

    private func select(_ tab: String) {
        switch tab {
        case Self.add:
            adding = true
        case "home":
            section = .home
            selection = "home"
        case let id where id.hasPrefix("module."):
            open(String(id.dropFirst("module.".count)))
        default:
            selection = tab
        }
    }

    private func open(_ module: String) {
        guard let target = ShellSection(rawValue: module), let first = target.tabs.first else { return }
        section = target
        selection = first.id
    }
}
