import SwiftUI

/// Finanzas' admin pages, listed flat in the section selector after Presupuestos.
enum FinanceMorePage: String, Hashable, CaseIterable {
    case accounts, categories, recurring, goals, debts, shared, settings

    var title: String {
        switch self {
        case .accounts: "Cuentas"
        case .categories: "Categorías"
        case .recurring: "Recurrentes"
        case .goals: "Objetivos"
        case .debts: "Deudas"
        case .shared: "Compartidos"
        case .settings: "Ajustes de Finanzas"
        }
    }

    /// Name in the header selector, where "Finanzas" already sits below it.
    var sectionTitle: String {
        self == .settings ? "Ajustes" : title
    }
}

/// One admin page as a Finanzas section root, with the screens its links push.
struct FinancePageView: View {
    let page: FinanceMorePage
    let api: APIClient
    var go: (FinanceRoute) -> Void

    var body: some View {
        destination(page)
            .navigationDestination(for: FinanceMorePage.self) { page in
                destination(page)
            }
            .navigationDestination(for: GoalRoute.self) { route in
                GoalDetailView(api: api, goalId: route.id)
            }
            .navigationDestination(for: ContactRoute.self) { route in
                ContactDetailView(api: api, contactId: route.id)
            }
            .navigationDestination(for: BanksRoute.self) { _ in
                BanksView(api: api, go: go)
            }
            .navigationDestination(for: AccountLink.self) { link in
                AccountLinkView(api: api, link: link, go: go)
            }
            .navigationDestination(for: BankLinkRoute.self) { route in
                BankLinkView(api: api, route: route) { _ in }
            }
    }

    @ViewBuilder
    private func destination(_ page: FinanceMorePage) -> some View {
        switch page {
        case .accounts: AccountsView(model: AccountsModel(api: api), go: go)
        case .categories: CategoriesView(model: CategoriesModel(api: api))
        case .recurring: RecurringView(model: RecurringModel(api: api))
        case .goals: GoalsView(model: GoalsModel(api: api))
        case .debts: DebtsView(model: DebtsModel(api: api))
        case .shared: SharedView(model: SharedModel(api: api))
        case .settings: FinanceSettingsView(model: FinanceSettingsModel(api: api))
        }
    }
}
