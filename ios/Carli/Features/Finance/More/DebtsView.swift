import SwiftUI

struct Debt: Decodable, Identifiable, Equatable {
    struct Contact: Decodable, Equatable { var name: String? }

    var id: String
    var name: String
    var direction: String
    var contactId: String?
    var contact: Contact?
    var principalCents: Int
    var paidCents: Int?
    var pendingCents: Int
    var progressBp: Int?
    var startDate: String
    var dueDate: String?
    var installmentCents: Int?
    var installmentsCount: Int?
    var installmentsPaid: Int?
    var recurringRuleId: String?
    var nextPaymentDate: String?
    var notes: String?
    var closed: Bool?

    var owesMe: Bool { direction == "owed_to_me" }
    var isClosed: Bool { closed == true }
    var percent: Int { (progressBp ?? 0) / 100 }
    var ratio: Double { Double(progressBp ?? 0) / 10000 }
    var directionLabel: String { owesMe ? "Te deben" : "Debes" }

    var installmentsLabel: String {
        guard let installment = installmentCents, installment != 0, let count = installmentsCount, count != 0 else {
            return "Sin plan de pagos"
        }
        return "\(Money.format(installment)) / mes · \(min(installmentsPaid ?? 0, count)) de \(count) cuotas"
    }

    var subtitle: String { [contact?.name, installmentsLabel].compactMap { $0 }.joined(separator: " · ") }

    var nextDateLabel: String? {
        if let next = nextPaymentDate.flatMap(CarliDate.day) { return "Próx. \(CarliDate.short(next))" }
        if let due = dueDate.flatMap(CarliDate.day) { return "Vence \(CarliDate.short(due))" }
        return nil
    }
}

struct DebtsOverview: Decodable {
    struct Meta: Decodable {
        var owedToMeCents: Int?
        var iOweCents: Int?
    }

    var data: [Debt]
    var meta: Meta?

    var open: [Debt] { data.filter { !$0.isClosed } }
    var closed: [Debt] { data.filter(\.isClosed) }
    func openCount(owesMe: Bool) -> Int { open.filter { $0.owesMe == owesMe }.count }
}

enum DebtsCopy {
    static func open(_ count: Int) -> String {
        switch count {
        case 0: "Nada pendiente"
        case 1: "1 deuda abierta"
        default: "\(count) deudas abiertas"
        }
    }

    static func balance(_ cents: Int) -> String {
        if cents > 0 { return "Te debe \(Money.format(cents))" }
        if cents < 0 { return "Le debes \(Money.format(-cents))" }
        return "En paz"
    }

    /// Checking first, as that is where loan payments usually come from.
    static func preferredAccount(_ accounts: [FinanceAccount]) -> String? {
        let active = accounts.filter { !$0.isArchived }
        return (active.first { $0.type == "checking" } ?? active.first)?.id
    }
}

@Observable
final class DebtsModel {
    enum State { case loading, loaded, failed(String) }

    var state: State = .loading
    var overview: DebtsOverview?
    var contacts: [FinanceContact] = []
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            overview = try await api.get("v1/finance/debts", query: ["include_closed": "1"])
            state = .loaded
        } catch {
            if overview == nil { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
        if let page: ContactsOverview = try? await api.get("v1/finance/contacts") { contacts = page.data }
    }
}

/// Más › Deudas: what you owe and are owed, each loan with its progress, and shared balances.
struct DebtsView: View {
    @State var model: DebtsModel
    @State private var form: DebtFormTarget?
    @State private var detail: Debt?
    @State private var showClosed = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                switch model.state {
                case .loading:
                    CarliCard { SkeletonBar(width: 200, height: 40) }
                    CarliCard { SkeletonBar(width: 300, height: 120) }
                case .failed(let message):
                    CardMessage(title: "No se han podido cargar las deudas", symbol: "exclamationmark.circle",
                                message: message, action: "Reintentar") { Task { await model.load() } }
                case .loaded:
                    if let overview = model.overview { content(overview) }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle("Deudas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nueva deuda", systemImage: "plus") { form = .new }
            }
        }
        .refreshable { await model.load() }
        .task { if model.overview == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await model.load() } }
        .sheet(item: $form) { target in
            DebtFormView(api: model.api, debt: target.debt, contacts: model.contacts) { toast = $0 }
        }
        .sheet(item: $detail) { debt in
            DebtDetailView(api: model.api, debt: debt, contacts: model.contacts) { toast = $0 }
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private func content(_ overview: DebtsOverview) -> some View {
        Grid(horizontalSpacing: CarliSpace.s12) {
            GridRow {
                StatCard(label: "Te deben", value: Money.format(overview.meta?.owedToMeCents ?? 0),
                         valueColor: CarliColor.positive, note: DebtsCopy.open(overview.openCount(owesMe: true)))
                StatCard(label: "Debes", value: Money.format(overview.meta?.iOweCents ?? 0),
                         note: DebtsCopy.open(overview.openCount(owesMe: false)))
            }
        }

        CarliCard(padding: 0) {
            Text("Préstamos y deudas")
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .accessibilityAddTraits(.isHeader)
                .padding([.horizontal, .top], CarliSpace.s16)
                .padding(.bottom, CarliSpace.s8)
            if overview.open.isEmpty {
                ContentUnavailableView {
                    Label("Sin deudas pendientes", systemImage: "banknote")
                } description: {
                    Text("Apunta préstamos y dinero que debes o te deben, y lleva la cuenta de cada pago.")
                } actions: {
                    Button("Nueva deuda") { form = .new }.buttonStyle(.glass)
                }
            } else {
                ForEach(Array(overview.open.enumerated()), id: \.element.id) { index, debt in
                    if index > 0 { Divider().padding(.horizontal, CarliSpace.s16) }
                    Button { detail = debt } label: { DebtTile(debt: debt) }.buttonStyle(.plain)
                }
            }
            if !overview.closed.isEmpty {
                Button {
                    withAnimation { showClosed.toggle() }
                } label: {
                    Label("Saldadas (\(overview.closed.count))", systemImage: showClosed ? "chevron.up" : "chevron.down")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CarliColor.text2)
                }
                .buttonStyle(.plain)
                .padding(CarliSpace.s16)
                if showClosed {
                    ForEach(overview.closed) { debt in
                        Button { detail = debt } label: {
                            HStack(spacing: CarliSpace.s12) {
                                IconBubble(symbol: "checkmark")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(debt.name).foregroundStyle(CarliColor.text)
                                    Text(debt.subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                                Spacer()
                                Text(Money.format(debt.principalCents)).monospacedDigit().foregroundStyle(CarliColor.text2)
                            }
                            .padding(.horizontal, CarliSpace.s16)
                            .padding(.vertical, CarliSpace.s8)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.bottom, CarliSpace.s8)

        sharedCard
    }

    private var sharedCard: some View {
        let top = model.contacts.filter { $0.balanceCents != 0 }.sorted { abs($0.balanceCents) > abs($1.balanceCents) }
        return CarliCard(padding: 0) {
            HStack {
                Text("Gastos compartidos")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CarliColor.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink("Ver todo", value: FinanceMorePage.shared)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CarliColor.brandInk)
            }
            .padding([.horizontal, .top], CarliSpace.s16)
            .padding(.bottom, CarliSpace.s8)
            if top.isEmpty {
                Text("Nadie con saldo. Reparte un gasto con un contacto y verás aquí quién te debe.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .padding([.horizontal, .bottom], CarliSpace.s16)
            } else {
                ForEach(top.prefix(5)) { contact in
                    NavigationLink(value: ContactRoute(id: contact.id)) {
                        HStack(spacing: CarliSpace.s12) {
                            Avatar(name: contact.name)
                            Text(contact.name).foregroundStyle(CarliColor.text).lineLimit(1)
                            Spacer(minLength: CarliSpace.s8)
                            BalanceLabel(cents: contact.balanceCents)
                        }
                        .padding(.horizontal, CarliSpace.s16)
                        .padding(.vertical, CarliSpace.s8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, CarliSpace.s8)
            }
        }
    }
}

private struct DebtTile: View {
    var debt: Debt

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(debt.name).font(.body.weight(.semibold)).foregroundStyle(CarliColor.text).lineLimit(1)
                    Text(debt.subtitle).font(.footnote).foregroundStyle(CarliColor.text3).lineLimit(1)
                }
                Spacer(minLength: CarliSpace.s8)
                CarliBadge(label: debt.directionLabel).fixedSize()
            }
            DebtFigures(debt: debt, trailing: debt.nextDateLabel).padding(.top, CarliSpace.s8)
            ProgressBar(ratio: debt.ratio).padding(.top, 6)
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s12)
        .contentShape(.rect)
    }
}

struct DebtFigures: View {
    var debt: Debt
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            (Text("Pendiente ")
                + Text(Money.format(debt.pendingCents)).fontWeight(.semibold).foregroundStyle(CarliColor.text)
                + Text(" de \(Money.format(debt.principalCents))"))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(CarliColor.text2)
            Spacer()
            if let trailing {
                Text(trailing).font(.footnote).foregroundStyle(CarliColor.text3)
            }
        }
    }
}

/// "Te debe" / "Le debes" over the amount, so a long name never pushes the figure onto two lines.
struct BalanceLabel: View {
    var cents: Int

    var body: some View {
        if cents == 0 {
            Text("En paz").font(.subheadline).foregroundStyle(CarliColor.text2)
        } else {
            VStack(alignment: .trailing, spacing: 0) {
                Text(cents > 0 ? "Te debe" : "Le debes").font(.caption).foregroundStyle(CarliColor.text2)
                Text(Money.format(abs(cents)))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(cents > 0 ? CarliColor.positive : CarliColor.text)
            }
            .fixedSize()
        }
    }
}

/// Initials on a soft disc.
struct Avatar: View {
    var name: String
    var size: CGFloat = 36

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(CarliColor.text)
            .frame(width: size, height: size)
            .background(CarliColor.surface2, in: .circle)
            .accessibilityHidden(true)
    }

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// One debt: figures, the payment form, its payments and close / delete.
struct DebtDetailView: View {
    let api: APIClient
    @State var debt: Debt
    var contacts: [FinanceContact]
    var onToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var payments: [FinanceTransaction]?
    @State private var accounts: [FinanceAccount] = []
    @State private var amountText = ""
    @State private var accountId: String?
    @State private var date = Date.now
    @State private var saving = false
    @State private var error: String?
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var toast: String?

    init(api: APIClient, debt: Debt, contacts: [FinanceContact], onToast: @escaping (String) -> Void) {
        self.api = api
        _debt = State(initialValue: debt)
        self.contacts = contacts
        self.onToast = onToast
        _amountText = State(initialValue: debt.installmentCents.map(Money.input) ?? "")
    }

    private var paymentHeading: String { debt.owesMe ? "Registrar cobro" : "Registrar pago" }
    private var effectiveAccountId: String? { accountId ?? DebtsCopy.preferredAccount(accounts) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CarliBadge(label: debt.directionLabel)
                        Spacer()
                        if debt.isClosed {
                            CarliBadge(label: "Saldada", symbol: "checkmark")
                        } else if let next = debt.nextDateLabel {
                            Text(next).font(.footnote).foregroundStyle(CarliColor.text3)
                        }
                    }
                    VStack(alignment: .leading, spacing: CarliSpace.s8) {
                        DebtFigures(debt: debt, trailing: "\(debt.percent) %")
                        ProgressBar(ratio: debt.ratio)
                    }
                    if let notes = debt.notes, !notes.isEmpty {
                        Text(notes).font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                }

                if !debt.isClosed {
                    Section(paymentHeading) {
                        AmountRow(title: "Importe", text: $amountText)
                        Picker("Cuenta", selection: Binding(get: { effectiveAccountId }, set: { accountId = $0 })) {
                            if effectiveAccountId == nil { Text("Elige una cuenta").tag(String?.none) }
                            ForEach(accounts.filter { !$0.isArchived }) { account in
                                Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
                            }
                        }
                        DatePicker("Fecha", selection: $date, displayedComponents: .date)
                        if let error { Text(error).foregroundStyle(CarliColor.negative) }
                        HStack {
                            Button("Todo lo pendiente") { amountText = Money.input(debt.pendingCents) }
                                .buttonStyle(.glass)
                            Spacer()
                            if saving { ProgressView() } else {
                                Button(paymentHeading, systemImage: "plus") { Task { await addPayment() } }
                                    .buttonStyle(.glassProminent)
                                    .tint(CarliColor.primary)
                                    .foregroundStyle(CarliColor.onPrimary)
                            }
                        }
                        .controlSize(.small)
                    }
                }

                Section(debt.owesMe ? "Cobros" : "Pagos") {
                    if let payments {
                        if payments.isEmpty {
                            Text("Aún no hay \(debt.owesMe ? "cobros" : "pagos") registrados.")
                                .font(.footnote)
                                .foregroundStyle(CarliColor.text2)
                        }
                        ForEach(payments) { payment in
                            paymentRow(payment)
                        }
                    } else {
                        ProgressView()
                    }
                }

                Section {
                    Button(debt.isClosed ? "Reabrir" : "Marcar como saldada",
                           systemImage: debt.isClosed ? "arrow.uturn.backward" : "checkmark") {
                        Task { await setClosed(!debt.isClosed) }
                    }
                    Button("Eliminar deuda", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                }
            }
            .navigationTitle(debt.name)
            .navigationSubtitle(debt.subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", role: .close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar deuda", systemImage: "pencil") { editing = true }
                }
            }
            .sheet(isPresented: $editing) {
                DebtFormView(api: api, debt: debt, contacts: contacts) { message in
                    toast = message
                    Task { await reload() }
                }
            }
            .confirmationDialog("¿Eliminar \(debt.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { Task { await delete() } }
            } message: {
                Text("Los pagos ya registrados se mantienen como movimientos. Si tenía cuotas, se elimina también su recurrente.")
            }
            .carliToast($toast)
            .task {
                if let page: AccountsPage = try? await api.get("v1/finance/accounts") { accounts = page.data }
                await loadPayments()
            }
        }
    }

    private func paymentRow(_ payment: FinanceTransaction) -> some View {
        HStack(spacing: CarliSpace.s12) {
            IconBubble(symbol: debt.owesMe ? "arrow.down.left" : "arrow.up.right", size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text([payment.description, payment.payee].compactMap { $0 }.first { !$0.isEmpty } ?? debt.name)
                    .foregroundStyle(CarliColor.text)
                Text("\(CarliDate.dayTitle(payment.date)) · \(payment.account.name)")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
            }
            Spacer()
            if payment.status == "pending" {
                CarliBadge(label: "Pendiente", symbol: "clock", tone: .warning)
            }
            Text(Money.format(payment.amountCents, .signed))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(payment.amountCents > 0 ? CarliColor.positive : CarliColor.text)
        }
        .swipeActions {
            Button("Borrar", systemImage: "trash", role: .destructive) { Task { await removePayment(payment) } }
                .tint(CarliColor.dangerFill)
        }
    }

    private func loadPayments() async {
        if let list: DataEnvelope<[FinanceTransaction]> = try? await api.get("v1/finance/debts/\(debt.id)/payments") {
            payments = list.data
        } else if payments == nil {
            payments = []
        }
    }

    private func reload() async {
        if let overview: DebtsOverview = try? await api.get("v1/finance/debts", query: ["include_closed": "1"]),
           let fresh = overview.data.first(where: { $0.id == debt.id }) {
            debt = fresh
        }
        await loadPayments()
    }

    private struct PaymentInput: Encodable {
        var accountId: String
        var amountCents: Int
        var date: String
    }

    private struct PaymentResult: Decodable {
        struct Meta: Decodable { var debt: Debt }
        var data: FinanceTransaction
        var meta: Meta
    }

    private func addPayment() async {
        guard let amount = Money.parse(amountText), amount > 0, let accountId = effectiveAccountId else {
            error = "Indica el importe y la cuenta."
            return
        }
        saving = true
        error = nil
        defer { saving = false }
        do {
            let result: PaymentResult = try await api.post("v1/finance/debts/\(debt.id)/payments",
                                                           body: PaymentInput(accountId: accountId, amountCents: amount,
                                                                              date: CarliDate.isoDay(date)))
            debt = result.meta.debt
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            toast = debt.isClosed ? "\(debt.name) saldada" : "\(paymentHeading): \(Money.format(result.data.amountCents, .signed))"
            await loadPayments()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido registrar el pago.")
        }
    }

    private func removePayment(_ payment: FinanceTransaction) async {
        do {
            try await api.delete("v1/finance/transactions/\(payment.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            toast = "Pago borrado"
            await reload()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar el pago.")
        }
    }

    private func setClosed(_ closed: Bool) async {
        do {
            let envelope: DataEnvelope<Debt> = try await api.patch("v1/finance/debts/\(debt.id)", body: ["closed": closed])
            debt = envelope.data
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            toast = closed ? "\(debt.name) marcada como saldada" : "\(debt.name) reabierta"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido actualizar la deuda.")
        }
    }

    private func delete() async {
        do {
            try await api.delete("v1/finance/debts/\(debt.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            onToast("\(debt.name) eliminada")
            dismiss()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido eliminar la deuda.")
        }
    }
}

enum DebtFormTarget: Identifiable {
    case new
    case edit(Debt)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let debt): debt.id
        }
    }

    var debt: Debt? {
        if case .edit(let debt) = self { return debt }
        return nil
    }
}

/// Body for POST/PATCH debts; nulls go out so clearing a field sticks.
struct DebtInput: Encodable {
    struct Plan: Encodable {
        var accountId: String
        var installmentCents: Int
        var installmentsCount: Int
        var firstPaymentDate: String
        var categoryId: String?

        private enum CodingKeys: String, CodingKey { case accountId, installmentCents, installmentsCount, firstPaymentDate, categoryId }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(accountId, forKey: .accountId)
            try container.encode(installmentCents, forKey: .installmentCents)
            try container.encode(installmentsCount, forKey: .installmentsCount)
            try container.encode(firstPaymentDate, forKey: .firstPaymentDate)
            try container.encode(categoryId, forKey: .categoryId)
        }
    }

    var name: String
    var direction: String
    var principalCents: Int
    var startDate: String
    var contactId: String?
    var dueDate: String?
    var notes: String?
    var plan: Plan?

    private enum CodingKeys: String, CodingKey { case name, direction, principalCents, startDate, contactId, dueDate, notes, plan }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(direction, forKey: .direction)
        try container.encode(principalCents, forKey: .principalCents)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(contactId, forKey: .contactId)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(plan, forKey: .plan)
    }
}

/// New / edit debt, optionally with a monthly instalment plan (creates a recurring rule).
struct DebtFormView: View {
    static let newContact = "__new"

    let api: APIClient
    let debt: Debt?
    var contacts: [FinanceContact]
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var owesMe = false
    @State private var principalText = ""
    @State private var name = ""
    @State private var contact: String?
    @State private var contactName = ""
    @State private var startDate = Date.now
    @State private var hasDue = false
    @State private var dueDate = CarliDate.calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var notes = ""
    @State private var hasPlan = false
    @State private var installmentText = ""
    @State private var countText = "12"
    @State private var firstPayment = CarliDate.calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var planAccountId: String?
    @State private var planCategoryId: String?
    @State private var accounts: [FinanceAccount] = []
    @State private var categories: [FinanceCategory] = []
    @State private var saving = false
    @State private var error: String?

    init(api: APIClient, debt: Debt?, contacts: [FinanceContact], onSaved: @escaping (String) -> Void) {
        self.api = api
        self.debt = debt
        self.contacts = contacts
        self.onSaved = onSaved
        if let debt {
            _owesMe = State(initialValue: debt.owesMe)
            _principalText = State(initialValue: Money.input(debt.principalCents))
            _name = State(initialValue: debt.name)
            _contact = State(initialValue: debt.contactId)
            _startDate = State(initialValue: CarliDate.day(debt.startDate) ?? .now)
            if let due = debt.dueDate.flatMap(CarliDate.day) {
                _hasDue = State(initialValue: true)
                _dueDate = State(initialValue: due)
            }
            _notes = State(initialValue: debt.notes ?? "")
        }
    }

    private var canPlan: Bool { debt?.recurringRuleId == nil }
    private var effectivePlanAccount: String? { planAccountId ?? DebtsCopy.preferredAccount(accounts) }
    private var count: Int? { Int(countText.trimmingCharacters(in: .whitespaces)) }

    private var planValid: Bool {
        guard hasPlan, canPlan else { return true }
        return (Money.parse(installmentText) ?? 0) > 0 && (1...600).contains(count ?? 0) && effectivePlanAccount != nil
    }

    private var canSave: Bool {
        !saving && !name.trimmingCharacters(in: .whitespaces).isEmpty && (Money.parse(principalText) ?? 0) > 0 && planValid
            && (contact != Self.newContact || !contactName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    /// Expense categories, children indented under their parent.
    private var expenseCategories: [(FinanceCategory, Bool)] {
        categories.filter { $0.kind == "expense" && !$0.isArchived }.flatMap { parent in
            [(parent, false)] + (parent.children ?? []).filter { !$0.isArchived }.map { ($0, true) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Dirección", selection: $owesMe) {
                        Text("Debo").tag(false)
                        Text("Me deben").tag(true)
                    }
                    .pickerStyle(.segmented)
                    AmountRow(title: "Importe total", text: $principalText)
                    TextField("Concepto (Préstamo coche, Dinero a Luis…)", text: $name)
                }
                Section {
                    Picker(owesMe ? "Quién te lo debe" : "A quién se lo debes", selection: $contact) {
                        Text("Sin contacto").tag(String?.none)
                        ForEach(contacts.filter { !$0.isArchived || $0.id == contact }) { item in
                            Text(item.name).tag(Optional(item.id))
                        }
                        Text("Nuevo contacto…").tag(Optional(Self.newContact))
                    }
                    if contact == Self.newContact {
                        TextField("Nombre del contacto (Cetelem, Luis…)", text: $contactName)
                    }
                }
                Section {
                    DatePicker("Fecha", selection: $startDate, displayedComponents: .date)
                    Toggle("Fecha de vencimiento", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Vence", selection: $dueDate, displayedComponents: .date)
                    }
                }
                if canPlan {
                    Section {
                        Toggle(owesMe ? "Cobrar en cuotas mensuales" : "Pagar en cuotas mensuales", isOn: $hasPlan)
                        if hasPlan {
                            AmountRow(title: "Cuota mensual", text: $installmentText)
                            HStack {
                                Text("Número de cuotas")
                                Spacer()
                                TextField("12", text: $countText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 80)
                            }
                            DatePicker("Primera cuota", selection: $firstPayment, displayedComponents: .date)
                            Picker("Cuenta", selection: Binding(get: { effectivePlanAccount }, set: { planAccountId = $0 })) {
                                if effectivePlanAccount == nil { Text("Elige una cuenta").tag(String?.none) }
                                ForEach(accounts.filter { !$0.isArchived }) { account in
                                    Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
                                }
                            }
                            if !owesMe {
                                Picker("Categoría", selection: $planCategoryId) {
                                    Text("Sin categoría").tag(String?.none)
                                    ForEach(expenseCategories, id: \.0.id) { category, child in
                                        Text(child ? "   \(category.name)" : category.name).tag(Optional(category.id))
                                    }
                                }
                            }
                        }
                    } footer: {
                        if hasPlan { Text("Creamos un recurrente mensual con la cuota; cada cargo se descuenta de la deuda.") }
                    }
                }
                Section("Notas") {
                    TextField("Opcional", text: $notes, axis: .vertical)
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle(debt == nil ? "Nueva deuda" : "Editar deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Guardar", role: .confirm) { Task { await save() } }.disabled(!canSave)
                    }
                }
            }
            .task {
                if let page: AccountsPage = try? await api.get("v1/finance/accounts") { accounts = page.data }
                if let list: DataEnvelope<[FinanceCategory]> = try? await api.get("v1/finance/categories") { categories = list.data }
            }
        }
    }

    private struct ContactBody: Encodable {
        var name: String
        var notes: String?
    }

    private func save() async {
        guard canSave, let principal = Money.parse(principalText) else { return }
        saving = true
        error = nil
        defer { saving = false }
        do {
            var contactId = contact
            if contact == Self.newContact {
                let created: DataEnvelope<FinanceContact> = try await api.post(
                    "v1/finance/contacts", body: ContactBody(name: contactName.trimmingCharacters(in: .whitespaces)))
                contactId = created.data.id
                contact = created.data.id
            }
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            var plan: DebtInput.Plan?
            if hasPlan, canPlan, let installment = Money.parse(installmentText), let count, let account = effectivePlanAccount {
                plan = .init(accountId: account, installmentCents: installment, installmentsCount: count,
                             firstPaymentDate: CarliDate.isoDay(firstPayment), categoryId: owesMe ? nil : planCategoryId)
            }
            let body = DebtInput(name: name.trimmingCharacters(in: .whitespaces), direction: owesMe ? "owed_to_me" : "i_owe",
                                 principalCents: principal, startDate: CarliDate.isoDay(startDate), contactId: contactId,
                                 dueDate: hasDue ? CarliDate.isoDay(dueDate) : nil,
                                 notes: trimmedNotes.isEmpty ? nil : trimmedNotes, plan: plan)
            if let debt {
                let _: Empty = try await api.patch("v1/finance/debts/\(debt.id)", body: body)
            } else {
                let _: Empty = try await api.post("v1/finance/debts", body: body)
            }
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            onSaved(debt == nil ? "Deuda creada" : "Deuda actualizada")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar la deuda.")
        }
    }
}
