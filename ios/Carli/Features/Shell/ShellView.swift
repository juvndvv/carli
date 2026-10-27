import SwiftUI

/// A module's own sections, shown as a segmented control inside its tab.
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

    /// Filled, low-detail, rounded: one circle family so the bar reads as a set.
    var symbol: String {
        switch self {
        case .finance: "eurosign.circle.fill"
        case .tasks: "checkmark.circle.fill"
        case .notes: "pencil.circle.fill"
        case .habits: "repeat.circle.fill"
        }
    }

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
            Tab("Inicio", systemImage: "house.fill", value: "home") {
                if let home {
                    HomeView(model: home) { selection = $0 }
                }
            }

            ForEach(modules, id: \.self) { module in
                Tab(module.title, systemImage: module.symbol, value: module.rawValue) {
                    ModuleRootView(module: module)
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

/// A module tab: large title, its sections in a segmented control, "+" top right.
struct ModuleRootView: View {
    var module: ModuleTab
    @State private var section: ModuleSection
    @State private var adding = false

    init(module: ModuleTab) {
        self.module = module
        _section = State(initialValue: module.sections[0])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CarliSpace.s16) {
                    Picker("Sección", selection: $section) {
                        ForEach(module.sections) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)

                    ContentUnavailableView {
                        Label(section.title, systemImage: "hammer")
                    } description: {
                        Text("Esta sección todavía no está migrada a la app nativa.")
                    }
                    .padding(.top, CarliSpace.s48)
                }
                .padding(.horizontal, CarliSpace.s16)
            }
            .background(CarliColor.bg)
            .navigationTitle(module.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(module.addLabel, systemImage: "plus") { adding = true }
                        .buttonStyle(.glassProminent)
                        .tint(CarliColor.primary)
                }
            }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    PendingMigrationView(title: module.addLabel, symbol: "plus")
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

