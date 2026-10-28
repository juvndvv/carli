import SwiftUI

/// Pages reachable from Finanzas › Más.
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

    var subtitle: String {
        switch self {
        case .accounts: "Saldos, patrimonio y conciliación"
        case .categories: "Categorías de gasto e ingreso, etiquetas"
        case .recurring: "Suscripciones y cargos periódicos"
        case .goals: "Ahorro para metas"
        case .debts: "Préstamos y lo que te deben"
        case .shared: "Gastos a medias con tus contactos"
        case .settings: "Periodo, avisos y bancos conectados"
        }
    }

    var symbol: String {
        switch self {
        case .accounts: "building.columns.fill"
        case .categories: "tag.fill"
        case .recurring: "repeat"
        case .goals: "target"
        case .debts: "banknote.fill"
        case .shared: "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// Finanzas › Más: the admin pages of the module, one row each.
struct FinanceMoreView: View {
    let api: APIClient
    var go: (FinanceRoute) -> Void

    var body: some View {
        ScrollView {
            CarliCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(FinanceMorePage.allCases.enumerated()), id: \.element) { index, page in
                        if index > 0 { Divider().padding(.leading, 68) }
                        NavigationLink(value: page) {
                            HStack(spacing: CarliSpace.s12) {
                                Image(systemName: page.symbol)
                                    .font(.system(size: 16))
                                    .foregroundStyle(CarliColor.text)
                                    .frame(width: 40, height: 40)
                                    .background(CarliColor.surface2, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(CarliColor.text)
                                    Text(page.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(CarliColor.text2)
                                }
                                Spacer()
                                Chevron()
                            }
                            .padding(.horizontal, CarliSpace.s16)
                            .padding(.vertical, CarliSpace.s12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
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
