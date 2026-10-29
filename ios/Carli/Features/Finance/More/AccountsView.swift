import Charts
import SwiftUI

/// Data for Cuentas: every account plus the net worth.
@Observable
final class AccountsModel {
    enum State { case loading, loaded, failed(String) }

    var state: State = .loading
    var accounts: [FinanceAccount] = []
    var netWorthCents = 0
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var active: [FinanceAccount] { accounts.filter { !$0.isArchived } }
    var archived: [FinanceAccount] { accounts.filter(\.isArchived) }

    func load() async {
        do {
            let page: AccountsPage = try await api.get("v1/finance/accounts", query: ["include_archived": "1"])
            accounts = page.data
            netWorthCents = page.meta?.netWorthCents ?? page.data.filter { !$0.isArchived && $0.includeInNetWorth != false }.reduce(0) { $0 + ($1.ownBalanceCents ?? $1.balanceCents) }
            state = .loaded
        } catch {
            if accounts.isEmpty { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
    }

    /// PATCH a few fields; returns the toast text or the error.
    func update(_ account: FinanceAccount, _ changes: [String: Bool]) async throws {
        let _: DataEnvelope<FinanceAccount> = try await api.patch("v1/finance/accounts/\(account.id)", body: changes)
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        await load()
    }

    func delete(_ account: FinanceAccount) async throws {
        try await api.delete("v1/finance/accounts/\(account.id)")
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        await load()
    }
}

/// Finanzas › Cuentas: net worth, a card per account and archived ones on demand.
struct AccountsView: View {
    @State var model: AccountsModel
    var go: (FinanceRoute) -> Void

    @State private var showArchived = false
    @State private var editing: AccountEditTarget?
    @State private var reconciling: FinanceAccount?
    @State private var deleting: FinanceAccount?
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                switch model.state {
                case .loading:
                    CarliCard { SkeletonBar(width: 200, height: 40) }
                    CarliCard { SkeletonBar(width: 300, height: 120) }
                case .failed(let message):
                    CarliCard {
                        ContentUnavailableView {
                            Label("No se han podido cargar las cuentas", systemImage: "exclamationmark.circle")
                        } description: { Text(message) } actions: {
                            Button("Reintentar") { Task { await model.load() } }.buttonStyle(.glass)
                        }
                    }
                case .loaded:
                    if model.accounts.isEmpty {
                        CarliCard {
                            ContentUnavailableView {
                                Label("Aún no tienes cuentas", systemImage: "building.columns")
                            } description: {
                                Text("Crea tu cuenta corriente, tu tarjeta o el efectivo con su saldo actual y empieza a apuntar movimientos.")
                            } actions: {
                                Button("Añadir cuenta") { editing = .new }.buttonStyle(.glassProminent)
                            }
                        }
                    } else {
                        netWorthCard
                        ForEach(showArchived ? model.active + model.archived : model.active) { account in
                            AccountCard(account: account,
                                        open: { go(.transactions(TransactionFilters(allPeriods: true, accountIds: [account.id]))) },
                                        reconcile: { reconciling = account },
                                        menu: { menu(for: account) })
                        }
                        if !model.archived.isEmpty {
                            Button {
                                withAnimation { showArchived.toggle() }
                            } label: {
                                Label("\(model.archived.count == 1 ? "1 cuenta archivada" : "\(model.archived.count) cuentas archivadas") · \(showArchived ? "ocultar" : "mostrar")",
                                      systemImage: "archivebox")
                                    .font(.footnote)
                                    .foregroundStyle(CarliColor.text3)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, CarliSpace.s4)
                        }
                    }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle("Cuentas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nueva cuenta", systemImage: "plus") { editing = .new }
            }
        }
        .refreshable { await model.load() }
        .task { if model.accounts.isEmpty { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await model.load() } }
        .navigationDestination(for: FinanceAccount.self) { account in
            AccountDetailView(model: AccountDetailModel(api: model.api, account: account), go: go)
        }
        .sheet(item: $editing) { target in
            AccountFormView(model: AccountFormModel(api: model.api, account: target.account)) { toast = $0 }
        }
        .sheet(item: $reconciling) { account in
            ReconcileView(api: model.api, account: account) { toast = $0 }
        }
        .confirmationDialog("¿Eliminar \(deleting?.name ?? "la cuenta")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { account in
            Button("Eliminar", role: .destructive) {
                Task {
                    do {
                        try await model.delete(account)
                        toast = "Cuenta eliminada"
                    } catch {
                        toast = error.apiMessage(fallback: "Tiene movimientos: archívala en lugar de eliminarla.")
                    }
                }
            }
        } message: { _ in
            Text("Solo se pueden eliminar cuentas sin movimientos. Esta acción no se puede deshacer.")
        }
        .carliToast($toast)
    }

    private var netWorthCard: some View {
        CarliCard {
            Text("Patrimonio neto")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
            Text(Money.format(model.netWorthCents))
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(CarliColor.text)
                .minimumScaleFactor(0.6)
            let count = model.active.count
            Text("\(count == 1 ? "1 cuenta" : "\(count) cuentas")\(model.active.contains(where: \.isCreditCard) ? " · las tarjetas de crédito restan" : "")")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
        }
    }

    @ViewBuilder
    private func menu(for account: FinanceAccount) -> some View {
        NavigationLink(value: account) { Label("Ver detalle", systemImage: "chart.xyaxis.line") }
        Button("Editar", systemImage: "pencil") { editing = .edit(account) }
        Button("Conciliar", systemImage: "checkmark.circle") { reconciling = account }
        let included = account.includeInNetWorth != false
        Button(included ? "Excluir del patrimonio" : "Incluir en el patrimonio", systemImage: included ? "eye.slash" : "eye") {
            Task {
                do {
                    try await model.update(account, ["include_in_net_worth": !included])
                    toast = included ? "\(account.name) ya no suma al patrimonio" : "\(account.name) suma al patrimonio"
                } catch { toast = error.apiMessage(fallback: "No se ha podido actualizar la cuenta.") }
            }
        }
        Button(account.isArchived ? "Desarchivar" : "Archivar", systemImage: account.isArchived ? "archivebox.fill" : "archivebox") {
            Task {
                do {
                    try await model.update(account, ["archived": !account.isArchived])
                    toast = account.isArchived ? "\(account.name) vuelve a estar activa" : "\(account.name) archivada"
                } catch { toast = error.apiMessage(fallback: "No se ha podido actualizar la cuenta.") }
            }
        }
        Button("Eliminar", systemImage: "trash", role: .destructive) { deleting = account }
    }
}

enum AccountEditTarget: Identifiable {
    case new
    case edit(FinanceAccount)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let account): account.id
        }
    }

    var account: FinanceAccount? {
        if case .edit(let account) = self { account } else { nil }
    }
}

struct AccountCard<MenuItems: View>: View {
    var account: FinanceAccount
    var open: () -> Void
    var reconcile: () -> Void
    @ViewBuilder var menu: () -> MenuItems

    var body: some View {
        CarliCard {
            HStack(spacing: CarliSpace.s12) {
                NavigationLink(value: account) {
                    HStack(spacing: CarliSpace.s12) {
                        Image(systemName: account.symbol)
                            .font(.system(size: 16))
                            .foregroundStyle(CarliColor.text)
                            .frame(width: 36, height: 36)
                            .background(CarliColor.surface2, in: .circle)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(CarliColor.text)
                                .lineLimit(1)
                            Text(account.subtitle)
                                .font(.footnote)
                                .foregroundStyle(CarliColor.text3)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if account.isArchived { CarliBadge(label: "Archivada", symbol: "archivebox") }
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Opciones de \(account.name)")
            }

            Text(Money.format(account.balanceCents))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(account.balanceCents < 0 && !account.isCreditCard ? CarliColor.negative : CarliColor.text)
                .padding(.top, CarliSpace.s16)

            AccountFigures(account: account)
                .padding(.top, CarliSpace.s4)

            HStack(spacing: CarliSpace.s8) {
                Button("Movimientos", systemImage: "list.bullet", action: open)
                Button("Conciliar", systemImage: "checkmark.circle", action: reconcile)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .padding(.top, CarliSpace.s12)
        }
        .opacity(account.isArchived ? 0.75 : 1)
    }
}

/// Credit usage for cards, pending vs confirmed otherwise, plus the bank's own balance.
struct AccountFigures: View {
    var account: FinanceAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if account.isCreditCard, let limit = account.creditLimitCents, limit > 0 {
                let used = account.usedCreditCents ?? 0
                ProgressBar(ratio: Double(used) / Double(limit))
                HStack {
                    Text("Dispuesto \(Money.format(used))")
                    Spacer()
                    Text("Disponible \(Money.format(account.availableCreditCents ?? 0))")
                }
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
                if let schedule = account.cardSchedule {
                    Text(schedule).font(.footnote).foregroundStyle(CarliColor.text3)
                }
            } else if let pending = account.pendingCents, pending != 0 {
                Text("Pendiente \(Money.format(pending, .signed)) · confirmado \(Money.format(account.clearedBalanceCents ?? account.balanceCents))")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text3)
            } else {
                Text("Todo confirmado").font(.footnote).foregroundStyle(CarliColor.text3)
            }
            if let bank = account.bank {
                BankBalanceLine(bank: bank)
            }
        }
    }
}

struct BankBalanceLine: View {
    var bank: FinanceAccount.Bank

    var body: some View {
        let difference = bank.differenceCents
        Label {
            VStack(alignment: .leading, spacing: 1) {
                if let balance = bank.balanceCents {
                    Text("\(bank.aspspName ?? "Banco"): \(Money.format(balance))\(difference == 0 ? " · cuadra" : difference.map { " · diferencia \(Money.format($0, .signed))" } ?? "")")
                } else {
                    Text("Vinculada con \(bank.aspspName ?? "el banco")")
                }
                if let at = bank.balanceAt.flatMap(CarliDate.instant) {
                    Text("Saldo del banco \(CarliDate.dateTime(at))").foregroundStyle(CarliColor.text3)
                }
            }
        } icon: {
            Image(systemName: difference == 0 ? "checkmark.seal" : "building.columns")
        }
        .font(.caption)
        .foregroundStyle(difference == nil || difference == 0 ? CarliColor.text2 : CarliColor.warning)
    }
}

// MARK: Detail

@Observable
final class AccountDetailModel {
    var account: FinanceAccount
    var recent: [FinanceTransaction] = []
    var history: [FinanceTransaction] = []
    var loading = true
    let api: APIClient

    init(api: APIClient, account: FinanceAccount) {
        self.api = api
        self.account = account
    }

    /// Balance at the end of each of the last 90 days, walking back from today's balance.
    var balancePoints: [(date: Date, cents: Int)] {
        let calendar = CarliDate.calendar
        let today = calendar.startOfDay(for: .now)
        var byDay: [Date: Int] = [:]
        for transaction in history {
            guard let day = CarliDate.day(transaction.date) else { continue }
            byDay[calendar.startOfDay(for: day), default: 0] += transaction.amountCents
        }
        let future = byDay.filter { $0.key > today }.values.reduce(0, +)
        var balance = account.balanceCents - future
        var points: [(Date, Int)] = []
        for offset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            points.append((date, balance))
            balance -= byDay[date] ?? 0
        }
        return points.reversed()
    }

    func load() async {
        if let envelope: DataEnvelope<FinanceAccount> = try? await api.get("v1/finance/accounts/\(account.id)") {
            account = envelope.data
        }
        let from = CarliDate.calendar.date(byAdding: .day, value: -90, to: .now).map(CarliDate.isoDay) ?? ""
        var collected: [FinanceTransaction] = []
        var cursor: String?
        for _ in 0..<5 {
            var query = ["account_id": account.id, "from": from, "per_page": "200"]
            if let cursor { query["cursor"] = cursor }
            guard let page: TransactionPage = try? await api.get("v1/finance/transactions", query: query) else { break }
            collected += page.data
            cursor = page.meta.nextCursor
            if page.meta.hasMore != true || cursor == nil { break }
        }
        history = collected
        recent = Array(collected.prefix(10))
        loading = false
    }
}

struct AccountDetailView: View {
    @State var model: AccountDetailModel
    var go: (FinanceRoute) -> Void
    @State private var editing = false
    @State private var reconciling = false
    @State private var editingTransaction: FinanceTransaction?
    @State private var toast: String?

    var body: some View {
        let account = model.account
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                CarliCard {
                    Text("Saldo actual").font(.footnote).foregroundStyle(CarliColor.text2)
                    Text(Money.format(account.balanceCents))
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(account.balanceCents < 0 && !account.isCreditCard ? CarliColor.negative : CarliColor.text)
                    if !account.isCreditCard {
                        HStack(spacing: CarliSpace.s16) {
                            figure("Confirmado", account.clearedBalanceCents ?? account.balanceCents)
                            figure("Pendiente", account.pendingCents ?? 0)
                        }
                        .padding(.top, CarliSpace.s8)
                    }
                    AccountFigures(account: account).padding(.top, CarliSpace.s8)
                    Button("Conciliar", systemImage: "checkmark.circle") { reconciling = true }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .padding(.top, CarliSpace.s12)
                }

                CarliCard {
                    Text("Evolución del saldo · 90 días")
                        .font(.headline)
                        .foregroundStyle(CarliColor.text)
                    if model.loading {
                        SkeletonBar(width: 300, height: 140).padding(.top, CarliSpace.s8)
                    } else {
                        Chart(model.balancePoints, id: \.date) { point in
                            LineMark(x: .value("Día", point.date), y: .value("Saldo", Double(point.cents) / 100))
                                .interpolationMethod(.stepEnd)
                                .foregroundStyle(CarliColor.chartAccent)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(CarliColor.border)
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 160)
                        .padding(.top, CarliSpace.s8)
                    }
                }

                CarliCard(padding: 0) {
                    HStack {
                        Text("Movimientos recientes").font(.headline).foregroundStyle(CarliColor.text)
                        Spacer()
                        Button("Ver todos") { go(.transactions(TransactionFilters(allPeriods: true, accountIds: [account.id]))) }
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(CarliSpace.s16)
                    if !model.loading, model.recent.isEmpty {
                        ContentUnavailableView("Sin movimientos", systemImage: "tray",
                                               description: Text("Aún no hay movimientos en los últimos 90 días."))
                    }
                    ForEach(Array(model.recent.enumerated()), id: \.element.id) { index, transaction in
                        if index > 0 { Divider().padding(.leading, 68) }
                        Button { editingTransaction = transaction } label: {
                            TransactionLine(transaction: transaction, accounts: [account.ref]).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle(account.name)
        .navigationSubtitle(account.subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar", systemImage: "pencil") { editing = true }
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await model.load() } }
        .sheet(isPresented: $editing) {
            AccountFormView(model: AccountFormModel(api: model.api, account: account)) { toast = $0 }
        }
        .sheet(isPresented: $reconciling) {
            ReconcileView(api: model.api, account: account) { toast = $0 }
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionSheet(model: TransactionFormModel(api: model.api, editing: transaction)) { toast = $0 }
        }
        .carliToast($toast)
    }

    private func figure(_ label: String, _ cents: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(CarliColor.text2)
            Text(Money.format(cents)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(CarliColor.text)
        }
    }
}
