import SwiftUI

/// Buscar: app sections that match locally plus server results (`v1/search`) across modules.
struct SearchView: View {
    let api: APIClient
    var enabledModules: Set<String>

    @Environment(AppRouter.self) private var router
    @State private var text = ""
    @State private var results: [SearchResult] = []
    @State private var searching = false
    @State private var searchedTerm = ""
    @State private var editing: FinanceTransaction?
    @State private var toast: String?
    @FocusState private var focused: Bool

    static let minimumLength = 2

    struct Shortcut: Identifiable {
        var title: String
        var subtitle: String?
        var symbol: String
        var path: String
        var module: String?
        var id: String { path + title }
    }

    static let sections: [Shortcut] = [
        Shortcut(title: "Inicio", symbol: "house", path: "/"),
        Shortcut(title: "Resumen", subtitle: "Finanzas", symbol: "square.grid.2x2", path: "/finanzas", module: AppModule.finance),
        Shortcut(title: "Movimientos", subtitle: "Finanzas", symbol: "list.bullet", path: "/finanzas/movimientos", module: AppModule.finance),
        Shortcut(title: "Cuentas", subtitle: "Finanzas", symbol: "building.columns", path: "/mas/cuentas", module: AppModule.finance),
        Shortcut(title: "Presupuestos", subtitle: "Finanzas", symbol: "gauge.with.dots.needle.50percent", path: "/finanzas/presupuestos", module: AppModule.finance),
        Shortcut(title: "Categorías", subtitle: "Finanzas", symbol: "tag", path: "/mas/categorias", module: AppModule.finance),
        Shortcut(title: "Recurrentes", subtitle: "Finanzas", symbol: "repeat", path: "/mas/recurrentes", module: AppModule.finance),
        Shortcut(title: "Objetivos", subtitle: "Finanzas", symbol: "target", path: "/mas/objetivos", module: AppModule.finance),
        Shortcut(title: "Deudas", subtitle: "Finanzas", symbol: "banknote", path: "/mas/deudas", module: AppModule.finance),
        Shortcut(title: "Compartidos", subtitle: "Finanzas", symbol: "person.2", path: "/mas/compartidos", module: AppModule.finance),
        Shortcut(title: "Ajustes de Finanzas", subtitle: "Finanzas", symbol: "gearshape", path: "/mas/ajustes-finanzas", module: AppModule.finance),
        Shortcut(title: "Tareas", subtitle: "Tareas", symbol: "checklist", path: "/tareas/hoy", module: AppModule.tasks),
        Shortcut(title: "Notas", subtitle: "Notas", symbol: "note.text", path: "/notas", module: AppModule.notes),
        Shortcut(title: "Lista de la compra", subtitle: "Notas", symbol: "cart", path: "/compra", module: AppModule.notes),
        Shortcut(title: "Hábitos", subtitle: "Hábitos", symbol: "flame", path: "/habitos/hoy", module: AppModule.habits),
        Shortcut(title: "Ajustes", subtitle: "Cuenta", symbol: "gearshape", path: "/ajustes"),
    ]

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .trimmingCharacters(in: .whitespaces)
    }

    /// Sections that match the term (the first six when it's empty), hiding disabled modules.
    static func matchingSections(_ term: String, enabled: Set<String>) -> [Shortcut] {
        let available = sections.filter { $0.module == nil || enabled.contains($0.module!) }
        let normalized = normalize(term)
        guard !normalized.isEmpty else { return Array(available.prefix(6)) }
        return available.filter { normalize("\($0.title) \($0.subtitle ?? "")").contains(normalized) }
    }

    var body: some View {
        let term = text.trimmingCharacters(in: .whitespaces)
        let sections = Self.matchingSections(term, enabled: enabledModules)
        let grouped = Dictionary(grouping: results) { $0.moduleName ?? "Resultados" }
        let groupOrder = results.reduce(into: [String]()) { order, result in
            let name = result.moduleName ?? "Resultados"
            if !order.contains(name) { order.append(name) }
        }
        List {
            ForEach(groupOrder, id: \.self) { group in
                Section(group) {
                    ForEach(grouped[group] ?? []) { result in
                        row(title: result.title, subtitle: result.subtitle, symbol: result.icon.map(CarliIcon.symbol) ?? "magnifyingglass",
                            enabled: destination(result) != nil) { open(result) }
                    }
                }
            }
            if !sections.isEmpty {
                Section("Secciones") {
                    ForEach(sections) { section in
                        row(title: section.title, subtitle: section.subtitle, symbol: section.symbol, enabled: true) {
                            router.open(url: section.path)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .overlay {
            if results.isEmpty && sections.isEmpty {
                let message = term.count < Self.minimumLength ? "Escribe al menos \(Self.minimumLength) letras."
                    : (searching || term != searchedTerm) ? "Buscando…" : "Sin resultados para «\(term)»."
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text3)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .navigationTitle("Buscar")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Busca movimientos, cuentas, secciones…")
        .searchFocused($focused)
        .onSubmit(of: .search) {
            if let first = results.first(where: { destination($0) != nil }) {
                open(first)
            } else if let section = sections.first {
                router.open(url: section.path)
            }
        }
        .task(id: term) {
            guard term.count >= Self.minimumLength else {
                results = []
                searchedTerm = term
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            searching = true
            defer { searching = false }
            results = await Self.search(api, term)
            searchedTerm = term
        }
        .onAppear { focused = true }
        .sheet(item: $editing) { transaction in
            TransactionSheet(model: TransactionFormModel(api: api, editing: transaction)) { toast = $0 }
        }
        .carliToast($toast)
    }

    static func search(_ api: APIClient, _ term: String) async -> [SearchResult] {
        struct Body: Decodable {
            var results: [SearchResult]?
            var data: [SearchResult]?
        }
        guard let body: Body = try? await api.get("v1/search", query: ["q": term]) else { return [] }
        return body.results ?? body.data ?? []
    }

    private enum Destination { case transaction(String, query: String), link(String) }

    private func destination(_ result: SearchResult) -> Destination? {
        if result.module == AppModule.finance, result.type == "transaction", let id = result.idString, !id.isEmpty {
            let query = result.url.flatMap { URLComponents(string: $0)?.queryItems?.first { $0.name == "q" }?.value } ?? ""
            return .transaction(id, query: query)
        }
        guard let url = result.url, AppLink.parse(url) != nil else { return nil }
        return .link(url)
    }

    private func open(_ result: SearchResult) {
        switch destination(result) {
        case .transaction(let id, let query):
            Task {
                do {
                    let envelope: DataEnvelope<FinanceTransaction> = try await api.get("v1/finance/transactions/\(id)")
                    editing = envelope.data
                } catch {
                    var filters = TransactionFilters()
                    filters.allPeriods = true
                    filters.query = query
                    router.open(AppLink(tab: ModuleTab.finance.rawValue, section: "transactions", filters: filters))
                }
            }
        case .link(let url):
            router.open(url: url)
        case nil:
            break
        }
    }

    private func row(title: String, subtitle: String?, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CarliSpace.s12) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(CarliColor.text)
                    .frame(width: 32, height: 32)
                    .background(CarliColor.surface2, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(CarliColor.text)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                }
                Spacer(minLength: 0)
                if enabled { Image(systemName: "arrow.right").font(.footnote).foregroundStyle(CarliColor.text3) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
