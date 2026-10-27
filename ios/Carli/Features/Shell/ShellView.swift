import SwiftUI
import UIKit

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

    /// Line symbols with little detail; the tab bar keeps them unfilled.
    var symbol: String {
        switch self {
        case .finance: "creditcard"
        case .tasks: "checkmark.circle"
        case .notes: "note.text"
        case .habits: "repeat"
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
            Tab(value: "home") {
                if let home {
                    HomeView(model: home) { selection = $0 }
                }
            } label: {
                Label { Text("Inicio") } icon: { Image.outline("house") }
            }

            ForEach(modules, id: \.self) { module in
                Tab(value: module.rawValue) {
                    ModuleRootView(module: module)
                } label: {
                    Label { Text(module.title) } icon: { Image.outline(module.symbol) }
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

extension Image {
    /// An SF Symbol flattened to a template bitmap. The system tab bar forces the
    /// `.fill` variant on symbol images; a plain image keeps the line version.
    static func outline(_ symbol: String, pointSize: CGFloat = 19) -> Image {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let source = UIImage(systemName: symbol, withConfiguration: config) else {
            return Image(systemName: symbol)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let bitmap = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
            source.withTintColor(.black, renderingMode: .alwaysOriginal).draw(at: .zero)
        }
        return Image(uiImage: bitmap.withRenderingMode(.alwaysTemplate))
    }
}
