import Foundation
import Testing
@testable import Carli

struct ShellTests {
    @Test func financeLinksOpenTheirSectionWithFilters() throws {
        let link = try #require(AppLink.parse("/finanzas/movimientos?sin_categoria=1&periodo=todos&categoria=a,b"))
        #expect(link.tab == "finance")
        #expect(link.section == "transactions")
        let filters = try #require(link.filters)
        #expect(filters.uncategorized)
        #expect(filters.allPeriods)
        #expect(filters.categoryIds == ["a", "b"])
    }

    @Test func financePagesAreSectionsOfTheirOwn() throws {
        let goal = try #require(AppLink.parse("/finanzas/objetivos/7"))
        #expect(goal.section == "goals")
        #expect(goal.steps == [.goal("7")])
        let account = try #require(AppLink.parse("/mas/cuentas/3"))
        #expect(account.section == "accounts")
        #expect(account.steps == [.account("3")])
        let bank = try #require(AppLink.parse("/finanzas/ajustes/bancos/c1/vincular?renovado=1"))
        #expect(bank.section == "settings")
        #expect(bank.steps == [.banks, .bankLink("c1", renewed: true)])
        #expect(AppLink.parse("/finanzas/recurrentes")?.section == "recurring")
        #expect(AppLink.parse("/finanzas/recurrentes")?.steps == [])
        #expect(AppLink.parse("/mas")?.section == "summary")
        #expect(ModuleTab.finance.sections.map(\.title)
            == ["Resumen", "Movimientos", "Presupuestos", "Cuentas", "Categorías", "Recurrentes", "Objetivos", "Deudas", "Compartidos", "Ajustes"])
    }

    @Test func homeLinks() throws {
        #expect(AppLink.parse("/pendientes?modulo=finance&tipo=transfer_suggestion")?.steps
            == [.home(.pending(module: "finance", type: "transfer_suggestion"))])
        #expect(AppLink.parse("/notificaciones")?.steps == [.home(.notifications)])
        #expect(AppLink.parse("/ajustes/notificaciones")?.steps == [.home(.settings), .settings(.notifications)])
        #expect(AppLink.parse("/mas/ajustes/seguridad")?.steps == [.home(.settings), .settings(.security)])
        #expect(AppLink.parse("/")?.tab == "home")
    }

    @Test func moduleLinks() throws {
        #expect(AppLink.parse("/habitos/habito/9/editar")?.steps == [.habit("9")])
        #expect(AppLink.parse("/tareas/tarea/4")?.steps == [.task("4")])
        #expect(AppLink.parse("/notas/n/abc")?.steps == [.note("abc")])
        #expect(AppLink.parse("/compra")?.section == "shopping")
        #expect(AppLink.parse("/finanzas/movimientos/nuevo?tipo=ingreso")?.newTransaction == .income)
    }

    @Test func habitLinksOpenInsideSalud() throws {
        let today = try #require(AppLink.parse("/habitos/hoy"))
        #expect(today.tab == "health")
        #expect(today.section == "habits-today")
        #expect(AppLink.parse("/habitos/habito/9")?.section == "habits")
        #expect(AppLink.moduleSettings(AppModule.habits)?.steps == [.habitsSettings])
    }

    @Test func saludLinks() throws {
        let weigh = try #require(AppLink.parse("/salud/pesarse"))
        #expect(weigh.tab == "health")
        #expect(weigh.weighIn)
        #expect(AppLink.parse("/salud")?.section == "summary")
        #expect(AppLink.parse("/salud/mediciones/m1")?.steps == [.measurement("m1")])
        #expect(AppLink.moduleSettings(AppModule.health)?.steps == [.healthSettings])
    }

    @Test func saludShowsOnlyTheSectionsOfModulesThatAreOn() {
        #expect(ModuleTab.health.sections(enabled: [AppModule.health]).map(\.id) == ["summary", "measurements", "trends"])
        #expect(ModuleTab.health.sections(enabled: [AppModule.habits]).map(\.id) == ["habits-today", "habits", "habits-progress"])
        #expect(ModuleTab.health.sections(enabled: [AppModule.health, AppModule.habits]).count == 6)
        #expect(ModuleTab.finance.sections(enabled: []).count == 10)
    }

    @Test func externalAndUnknownLinksAreIgnored() {
        #expect(AppLink.parse("https://example.com/finanzas") == nil)
        #expect(AppLink.parse("/desconocido") == nil)
        #expect(AppLink.parse("") == nil)
        #expect(AppLink.parse(nil) == nil)
    }

    @Test func linkFiltersReadDatesAndAmounts() {
        let filters = TransactionFilters.fromLink(["desde": "2026-10-01", "hasta": "2026-10-31", "min": "500",
                                                   "etiqueta": "#Viaje", "estado": "pendiente", "tipo": "gasto"])
        #expect(filters.from == "2026-10-01")
        #expect(filters.minCents == 500)
        #expect(filters.tags == ["viaje"])
        #expect(filters.pendingOnly)
        #expect(filters.kinds == [.expense])
        let query = filters.apiQuery(currentPeriodId: "p1")
        #expect(query["period_id"] == nil)
        #expect(query["from"] == "2026-10-01")
        #expect(query["tag"] == "viaje")
    }

    @Test func pendingMetaReadsCamelCasedKeys() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let item = try decoder.decode(PendingItem.self, from: Data("""
        {"module":"finance","type":"uncategorized_transaction","id":"x1","title":"Mercadona","date":"2026-10-27",
         "amount_cents":-1250,"meta":{"transaction_id":"t9","source":"bank"}}
        """.utf8))
        #expect(item.meta("transaction_id") == "t9")
        #expect(item.meta("source") == "bank")
        #expect(item.id == "finance:uncategorized_transaction:x1")
    }

    @Test func timeAgo() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CarliDate.timeAgo(now.addingTimeInterval(-30), now: now) == "ahora")
        #expect(CarliDate.timeAgo(now.addingTimeInterval(-300), now: now) == "hace 5 minutos")
        #expect(CarliDate.timeAgo(now.addingTimeInterval(-86_400), now: now) == "ayer")
    }

    @Test func searchSectionsHideDisabledModules() {
        let sections = SearchView.matchingSections("compra", enabled: [AppModule.finance])
        #expect(sections.isEmpty)
        #expect(SearchView.matchingSections("categorias", enabled: [AppModule.finance]).map(\.title) == ["Categorías"])
    }

    @Test func passwordRules() {
        #expect(SecuritySettingsView.passwordProblem(current: "a", password: "short", confirmation: "short") != nil)
        #expect(SecuritySettingsView.passwordProblem(current: "a", password: "longenough", confirmation: "different") == "Las contraseñas nuevas no coinciden.")
        #expect(SecuritySettingsView.passwordProblem(current: "a", password: "longenough", confirmation: "longenough") == nil)
        #expect(ProfileSettingsView.isValid(name: "Juan", email: "j@x.es"))
        #expect(!ProfileSettingsView.isValid(name: " ", email: "j@x.es"))
    }
}

struct TransactionToolsTests {
    @Test func tagsAreNormalized() {
        #expect(TransactionFormModel.parseTags("#Viaje, casa  ##Trabajo") == ["viaje", "casa", "trabajo"])
        #expect(BulkEditSheet.parseTags(" , ") == [])
    }

    @Test func transferNoticeMatchesSource() {
        #expect(TransactionSheet.transferNotice("confirmed") == "Confirmaste que es una transferencia entre tus cuentas.")
        #expect(TransactionSheet.transferNotice("linked") == "Transferencia con una cuenta sin conexión al banco.")
        #expect(TransactionSheet.transferNotice("auto").hasPrefix("Detectada"))
    }
}
