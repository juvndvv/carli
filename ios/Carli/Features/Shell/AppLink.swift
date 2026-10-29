import Foundation
import Observation

/// Settings screens pushed from Inicio › Ajustes.
enum SettingsPage: String, Hashable {
    case profile, security, notifications, modules, appearance, scaleLab
}

/// One screen pushed on top of a tab's root, in order.
enum AppLinkStep: Hashable {
    case home(HomeRoute)
    case settings(SettingsPage)
    case financePage(FinanceMorePage)
    case account(String), goal(String), contact(String), banks, bankLink(String, renewed: Bool)
    case task(String), taskList(String), template(String), tasksSettings
    case habit(String), habitsSettings
    case measurement(String), healthSettings
    case note(String), folder(String), notesCollection(trash: Bool), notesSettings
}

/// Where a notification, push, pending item, search hit or quick action leads: a tab, the
/// section inside it, and the screens to push. Flutter paths (`/finanzas/movimientos?…`,
/// `/mas/objetivos/12`, `/habitos/habito/3`…) are parsed into this.
struct AppLink: Equatable, Identifiable {
    var id = UUID()
    var tab: String
    var section: String?
    var steps: [AppLinkStep] = []
    var filters: TransactionFilters?
    /// Opens the new-movement sheet (quick action, `/finanzas/movimientos/nuevo`).
    var newTransaction: TransactionFormModel.Kind?
    /// Opens a movement's sheet (a search hit).
    var transactionId: String?
    /// Opens "Pesarse" in Salud (the weigh-in reminder).
    var weighIn = false

    static func == (lhs: AppLink, rhs: AppLink) -> Bool { lhs.id == rhs.id }

    static func home(_ steps: AppLinkStep...) -> AppLink { AppLink(tab: "home", steps: steps) }

    /// Maps a server or Flutter route to a native destination; nil for anything unknown or external.
    static func parse(_ raw: String?) -> AppLink? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty,
              let components = URLComponents(string: raw), components.scheme == nil, components.host == nil else { return nil }
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard let value = item.value else { continue }
            query[item.name] = query[item.name].map { "\($0),\(value)" } ?? value
        }
        let segments = components.path.split(separator: "/").map(String.init)
        return route(segments, query)
    }

    private static func route(_ s: [String], _ query: [String: String]) -> AppLink? {
        let finance = ModuleTab.finance.rawValue
        // Finanzas' admin pages are sections of their own, picked from the header selector.
        func page(_ page: FinanceMorePage, _ steps: AppLinkStep...) -> AppLink { AppLink(tab: finance, section: page.rawValue, steps: steps) }
        func financeSettings(_ extra: [AppLinkStep] = []) -> AppLink {
            AppLink(tab: finance, section: FinanceMorePage.settings.rawValue, steps: extra)
        }
        let financePages: [String: FinanceMorePage] = ["cuentas": .accounts, "categorias": .categories, "recurrentes": .recurring,
                                                          "objetivos": .goals, "deudas": .debts, "compartidos": .shared]
        let settingsPages: [String: SettingsPage] = ["perfil": .profile, "seguridad": .security, "avisos": .notifications,
                                                     "notificaciones": .notifications, "modulos": .modules, "apariencia": .appearance]

        func detail(_ page: FinanceMorePage, _ id: String) -> AppLink? {
            switch page {
            case .accounts: page(.accounts, .account(id))
            case .goals: page(.goals, .goal(id))
            case .shared: page(.shared, .contact(id))
            default: nil
            }
        }

        func settings(_ parts: ArraySlice<String>) -> AppLink {
            if parts.first == "modulo", let module = parts.dropFirst().first { return moduleSettings(module) ?? .home(.home(.settings)) }
            guard let first = parts.first, let page = settingsPages[first] else { return .home(.home(.settings)) }
            return .home(.home(.settings), .settings(page))
        }

        let rest = Array(s.dropFirst())
        func at(_ index: Int) -> String? { rest.indices.contains(index) ? rest[index] : nil }
        let bankLink: (String) -> [AppLinkStep] = { [.banks, .bankLink($0, renewed: query["renovado"] == "1")] }

        switch s.first {
        case nil:
            return AppLink(tab: "home")
        case "finanzas":
            switch (rest.count, at(0)) {
            case (0, _): return AppLink(tab: finance, section: "summary")
            case (2, "movimientos") where at(1) == "nuevo":
                return AppLink(tab: finance, section: "transactions", filters: TransactionFilters(),
                               newTransaction: query["tipo"] == "ingreso" ? .income : query["tipo"] == "transferencia" ? .transfer : .expense)
            case (_, "movimientos"):
                return AppLink(tab: finance, section: "transactions", filters: .fromLink(query),
                               newTransaction: query["nuevo"] == "1" ? .expense : nil)
            case (1, "presupuestos"): return AppLink(tab: finance, section: "budgets")
            case (1, "ajustes"): return financeSettings()
            case (2, "ajustes") where at(1) == "bancos": return financeSettings([.banks])
            case (4, "ajustes") where at(1) == "bancos" && at(3) == "vincular": return financeSettings(bankLink(rest[2]))
            case (1, let list?): return financePages[list].map { page($0) }
            case (2, let list?): return financePages[list].flatMap { detail($0, rest[1]) }
            default: return nil
            }
        case "mas":
            switch (rest.count, at(0)) {
            case (0, _): return AppLink(tab: finance, section: "summary")
            case (_, "ajustes"): return settings(rest.dropFirst())
            case (1, "ajustes-finanzas"): return financeSettings()
            case (2, "ajustes-finanzas") where at(1) == "bancos": return financeSettings([.banks])
            case (4, "ajustes-finanzas") where at(1) == "bancos" && at(3) == "vincular": return financeSettings(bankLink(rest[2]))
            case (1, let list?): return financePages[list].map { page($0) }
            case (2, let list?): return financePages[list].flatMap { detail($0, rest[1]) }
            default: return nil
            }
        case "pendientes":
            return .home(.home(.pending(module: query["modulo"], type: query["tipo"])))
        case "notificaciones":
            return .home(.home(.notifications))
        case "buscar":
            return .home(.home(.search))
        case "ajustes":
            return settings(rest[...])
        case "proximamente":
            return AppLink(tab: "home")
        case "tareas":
            let tasks = ModuleTab.tasks.rawValue
            switch (rest.count, at(0)) {
            case (0, _), (1, "hoy"): return AppLink(tab: tasks, section: "today")
            case (1, "proximas"): return AppLink(tab: tasks, section: "upcoming")
            case (1, "listas"): return AppLink(tab: tasks, section: "lists")
            case (2, "listas"): return AppLink(tab: tasks, section: "lists", steps: [.taskList(rest[1])])
            case (1, "plantillas"): return AppLink(tab: tasks, section: "templates")
            case (2, "plantillas") where at(1) == "nueva": return AppLink(tab: tasks, section: "templates")
            case (2, "plantillas"): return AppLink(tab: tasks, section: "templates", steps: [.template(rest[1])])
            case (2, "tarea"): return AppLink(tab: tasks, section: "today", steps: [.task(rest[1])])
            case (1, "ajustes"): return AppLink(tab: tasks, section: "today", steps: [.tasksSettings])
            default: return nil
            }
        case "habitos":
            // Hábitos lives inside Salud; the old paths keep working.
            let health = ModuleTab.health.rawValue
            switch (rest.count, at(0)) {
            case (0, _), (1, "hoy"), (1, "nuevo"): return AppLink(tab: health, section: "habits-today")
            case (1, "lista"): return AppLink(tab: health, section: "habits")
            case (1, "progreso"): return AppLink(tab: health, section: "habits-progress")
            case (1, "ajustes"): return AppLink(tab: health, section: "habits", steps: [.habitsSettings])
            case (_, "habito") where rest.count >= 2: return AppLink(tab: health, section: "habits", steps: [.habit(rest[1])])
            default: return nil
            }
        case "salud":
            let health = ModuleTab.health.rawValue
            switch (rest.count, at(0)) {
            case (0, _), (1, "resumen"): return AppLink(tab: health, section: "summary")
            case (1, "pesarse"): return AppLink(tab: health, section: "summary", weighIn: true)
            case (1, "mediciones"): return AppLink(tab: health, section: "measurements")
            case (2, "mediciones"): return AppLink(tab: health, section: "measurements", steps: [.measurement(rest[1])])
            case (1, "tendencias"): return AppLink(tab: health, section: "trends")
            case (1, "ajustes"): return AppLink(tab: health, section: "summary", steps: [.healthSettings])
            default: return nil
            }
        case "notas":
            let notes = ModuleTab.notes.rawValue
            switch (rest.count, at(0)) {
            case (0, _): return AppLink(tab: notes, section: "all")
            case (2, "n"): return AppLink(tab: notes, section: "all", steps: [.note(rest[1])])
            case (2, "carpeta"): return AppLink(tab: notes, section: "all", steps: [.folder(rest[1])])
            case (1, "archivadas"): return AppLink(tab: notes, section: "all", steps: [.notesCollection(trash: false)])
            case (1, "papelera"): return AppLink(tab: notes, section: "all", steps: [.notesCollection(trash: true)])
            case (1, "ajustes"): return AppLink(tab: notes, section: "all", steps: [.notesSettings])
            default: return nil
            }
        case "compra":
            return AppLink(tab: ModuleTab.notes.rawValue, section: "shopping")
        default:
            return nil
        }
    }

    /// "Ajustes de <módulo>" lives inside each module.
    static func moduleSettings(_ module: String) -> AppLink? {
        switch module {
        case AppModule.finance: AppLink(tab: ModuleTab.finance.rawValue, section: FinanceMorePage.settings.rawValue)
        case AppModule.tasks: AppLink(tab: ModuleTab.tasks.rawValue, section: "today", steps: [.tasksSettings])
        case AppModule.notes: AppLink(tab: ModuleTab.notes.rawValue, section: "all", steps: [.notesSettings])
        case AppModule.habits: AppLink(tab: ModuleTab.health.rawValue, section: "habits", steps: [.habitsSettings])
        case AppModule.health: AppLink(tab: ModuleTab.health.rawValue, section: "summary", steps: [.healthSettings])
        default: nil
        }
    }
}

/// Hands links to the tab that owns them. ShellView switches tabs; each tab's root consumes
/// the link addressed to it (section, filters, pushes) and clears it.
@Observable
final class AppRouter {
    private(set) var pending: AppLink?
    /// The tab the last link asked for. Kept apart from `pending` because an already loaded tab may
    /// take its link before ShellView gets to switch.
    private(set) var request: (id: UUID, tab: String)?

    func open(_ link: AppLink) {
        pending = link
        request = (link.id, link.tab)
    }

    /// Opens a server route; anything unknown falls back to the notifications inbox when asked.
    @discardableResult
    func open(url: String?, fallback: AppLink? = nil) -> Bool {
        if let link = AppLink.parse(url) {
            open(link)
            return true
        }
        if let fallback { open(fallback) }
        return false
    }

    /// Returns and clears the pending link when it belongs to `tab`.
    func take(for tab: String) -> AppLink? {
        guard let link = pending, link.tab == tab else { return nil }
        pending = nil
        return link
    }

    func drop() {
        pending = nil
    }

    /// ShellView has switched to (or refused) the requested tab.
    func settle() {
        request = nil
    }
}
