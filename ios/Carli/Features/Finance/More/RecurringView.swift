import SwiftUI

struct RecurringRule: Decodable, Identifiable, Equatable {
    struct PendingTransaction: Decodable, Equatable {
        var id: String
        var date: String
        var amountCents: Int
    }

    var id: String
    var name: String
    var accountId: String
    var account: AccountRef
    var categoryId: String?
    var category: CategoryRef?
    var kind: String
    var amountCents: Int
    var payee: String?
    var description: String?
    var frequency: String
    var interval: Int?
    var dayOfMonth: Int?
    var startDate: String
    var endDate: String?
    var nextOccurrence: String?
    var mode: String?
    var remindDaysBefore: Int?
    var isSubscription: Bool?
    var cancelled: Bool?
    var active: Bool?
    var monthlyCostCents: Int?
    var yearlyCostCents: Int?
    var pendingTransaction: PendingTransaction?

    var isCancelled: Bool { cancelled == true }
    var symbol: String { CarliIcon.symbol(category?.icon ?? (kind == "income" ? "briefcase" : "repeat")) }

    var frequencyLabel: String {
        RecurringRule.frequencyLabel(frequency: frequency, interval: interval ?? 1,
                                     start: CarliDate.day(startDate) ?? .now, dayOfMonth: dayOfMonth)
    }

    var subtitle: String {
        var parts = [frequencyLabel]
        if let pending = pendingTransaction, let date = CarliDate.day(pending.date) {
            parts.append("pendiente del \(CarliDate.short(date))")
        } else if let next = nextOccurrence.flatMap(CarliDate.day), !isCancelled {
            parts.append("próximo \(CarliDate.short(next))")
        } else if nextOccurrence == nil, !isCancelled {
            parts.append("finalizado")
        }
        return parts.joined(separator: " · ")
    }

    static func frequencyLabel(frequency: String, interval: Int, start: Date, dayOfMonth: Int?) -> String {
        let every = max(interval, 1)
        let calendar = CarliDate.calendar
        switch frequency {
        case "daily":
            return every == 1 ? "Diario" : "Cada \(every) días"
        case "weekly":
            let weekday = CarliDate.weekdays[calendar.component(.weekday, from: start) - 1]
            return every == 1 ? "Semanal · \(weekday)" : "Cada \(every) semanas · \(weekday)"
        case "yearly":
            return "\(every == 1 ? "Anual" : "Cada \(every) años") · \(CarliDate.short(start))"
        default:
            let base = every == 1 ? "Mensual" : every == 3 ? "Trimestral" : every == 6 ? "Semestral" : "Cada \(every) meses"
            return "\(base) · día \(dayOfMonth ?? calendar.component(.day, from: start))"
        }
    }
}

struct RecurringRulesPage: Decodable {
    struct Meta: Decodable {
        struct Subscriptions: Decodable {
            var count: Int?
            var monthlyCents: Int?
            var yearlyCents: Int?
        }
        var activeCount: Int?
        var monthlyTotalCents: Int?
        var subscriptions: Subscriptions?
    }

    var data: [RecurringRule]
    var meta: Meta?
}

@Observable
final class RecurringModel {
    enum Tab: String, CaseIterable { case all = "Todos", subscriptions = "Suscripciones", pending = "Pendientes", cancelled = "Canceladas" }

    var rules: [RecurringRule] = []
    var meta: RecurringRulesPage.Meta?
    var reminderDays: Int?
    var loaded = false
    var error: String?
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var pendingCount: Int { rules.filter { $0.pendingTransaction != nil }.count }

    func visible(_ tab: Tab) -> [RecurringRule] {
        rules.filter { rule in
            switch tab {
            case .all: !rule.isCancelled
            case .subscriptions: rule.isSubscription == true && !rule.isCancelled
            case .pending: rule.pendingTransaction != nil
            case .cancelled: rule.isCancelled
            }
        }
    }

    /// Active subscriptions charging in the next 30 days, soonest first.
    var upcomingSubscriptions: [RecurringRule] {
        let today = CarliDate.calendar.startOfDay(for: .now)
        guard let limit = CarliDate.calendar.date(byAdding: .day, value: 30, to: today) else { return [] }
        return rules.filter { rule in
            guard rule.isSubscription == true, !rule.isCancelled, rule.active == true,
                  let next = rule.nextOccurrence.flatMap(CarliDate.day) else { return false }
            return next >= today && next <= limit
        }
        .sorted { ($0.nextOccurrence ?? "") < ($1.nextOccurrence ?? "") }
        .prefix(5).map { $0 }
    }

    func load() async {
        do {
            let page: RecurringRulesPage = try await api.get("v1/finance/recurring-rules", query: ["include_cancelled": "1"])
            rules = page.data
            meta = page.meta
            error = nil
        } catch {
            if rules.isEmpty { self.error = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
        if let settings: DataEnvelope<FinanceSettingsFull> = try? await api.get("v1/finance/settings") {
            reminderDays = settings.data.remindDaysBefore
        }
        loaded = true
    }

    func setCancelled(_ rule: RecurringRule, _ cancelled: Bool) async throws {
        let _: Empty = try await api.patch("v1/finance/recurring-rules/\(rule.id)", body: ["cancelled": cancelled])
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        await load()
    }

    func delete(_ rule: RecurringRule) async throws {
        try await api.delete("v1/finance/recurring-rules/\(rule.id)")
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        await load()
    }
}

/// Más › Recurrentes: subscriptions totals, upcoming charges and every rule.
struct RecurringView: View {
    @State var model: RecurringModel
    @State private var tab: RecurringModel.Tab = .all
    @State private var form: RecurringFormTarget?
    @State private var confirming: RecurringRule?
    @State private var toast: String?

    var body: some View {
        List {
            Section {
                Picker("Vista", selection: $tab) {
                    ForEach(RecurringModel.Tab.allCases, id: \.self) { tab in
                        Text(tab == .pending && model.pendingCount > 0 ? "\(tab.rawValue) (\(model.pendingCount))" : tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                Grid(horizontalSpacing: CarliSpace.s12) {
                    GridRow {
                        StatCard(label: "Suscripciones al mes", value: Money.format(model.meta?.subscriptions?.monthlyCents ?? 0),
                                 note: (model.meta?.subscriptions?.count ?? 0) == 1 ? "1 activa" : "\(model.meta?.subscriptions?.count ?? 0) activas")
                        StatCard(label: "Al año", value: Money.format(model.meta?.subscriptions?.yearlyCents ?? 0))
                    }
                }
                StatCard(label: "Aviso", value: model.reminderDays.map(Self.reminderLabel) ?? "—",
                         note: "Notificación push a las 09:00")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            if tab == .subscriptions, !model.upcomingSubscriptions.isEmpty {
                Section("Próximos cargos") {
                    ForEach(model.upcomingSubscriptions) { rule in
                        RowLayout(symbol: rule.symbol, soft: false, title: rule.name, subtitle: upcomingLabel(rule)) { amount(rule) }
                            .listRowInsets(EdgeInsets())
                    }
                }
            }

            Section {
                let visible = model.visible(tab)
                if let error = model.error {
                    Text(error).foregroundStyle(CarliColor.negative)
                } else if model.loaded, visible.isEmpty {
                    emptyState
                }
                ForEach(visible) { rule in
                    Button { form = .edit(rule) } label: {
                        RowLayout(symbol: rule.symbol, soft: rule.isCancelled, title: rule.name, subtitle: rule.subtitle) {
                            VStack(alignment: .trailing, spacing: 2) {
                                amount(rule)
                                if rule.pendingTransaction != nil {
                                    CarliBadge(label: "Por confirmar", symbol: "clock", tone: .warning)
                                } else if rule.isSubscription == true {
                                    CarliBadge(label: "Suscripción", symbol: "repeat")
                                }
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .opacity(rule.isCancelled ? 0.6 : 1)
                    .swipeActions(edge: .leading) {
                        if canConfirm(rule) {
                            Button(rule.pendingTransaction != nil ? "Confirmar" : "Registrar", systemImage: "checkmark") { confirming = rule }
                                .tint(CarliColor.positive)
                        }
                    }
                    .contextMenu { actions(rule) }
                }
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, CarliSpace.s4, for: .scrollContent)
        .navigationTitle("Recurrentes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuevo recurrente", systemImage: "plus") { form = .new(subscription: tab == .subscriptions) }
            }
        }
        .refreshable { await model.load() }
        .task { if !model.loaded { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await model.load() } }
        .sheet(item: $form) { target in
            RecurringRuleForm(model: model, target: target) { toast = $0 }
        }
        .sheet(item: $confirming) { rule in
            ConfirmOccurrenceView(api: model.api, rule: rule) { toast = $0 }
        }
        .carliToast($toast)
    }

    static func reminderLabel(_ days: Int) -> String {
        days == 0 ? "El mismo día" : days == 1 ? "1 día antes" : "\(days) días antes"
    }

    private func canConfirm(_ rule: RecurringRule) -> Bool {
        !rule.isCancelled && (rule.pendingTransaction != nil || rule.nextOccurrence != nil)
    }

    @ViewBuilder
    private func actions(_ rule: RecurringRule) -> some View {
        Button("Editar", systemImage: "pencil") { form = .edit(rule) }
        if canConfirm(rule) {
            Button(rule.pendingTransaction != nil ? "Confirmar cargo pendiente" : "Registrar el próximo cargo ya", systemImage: "checkmark") {
                confirming = rule
            }
        }
        if rule.isCancelled {
            Button("Reactivar", systemImage: "arrow.counterclockwise") { setCancelled(rule, false) }
        } else {
            Button(rule.isSubscription == true ? "Cancelar suscripción" : "Cancelar recurrente", systemImage: "xmark.circle", role: .destructive) {
                setCancelled(rule, true)
            }
        }
    }

    private func setCancelled(_ rule: RecurringRule, _ cancelled: Bool) {
        Task {
            do {
                try await model.setCancelled(rule, cancelled)
                toast = cancelled ? "\(rule.name) cancelada" : "\(rule.name) reactivada"
            } catch { toast = error.apiMessage(fallback: "No se ha podido actualizar el recurrente.") }
        }
    }

    private func amount(_ rule: RecurringRule) -> some View {
        Text(Money.format(rule.amountCents, .signed))
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(rule.amountCents > 0 ? CarliColor.positive : CarliColor.text)
    }

    private func upcomingLabel(_ rule: RecurringRule) -> String {
        guard let next = rule.nextOccurrence else { return rule.account.name }
        let today = CarliDate.calendar.startOfDay(for: .now)
        let days = CarliDate.day(next).map { CarliDate.calendar.dateComponents([.day], from: today, to: $0).day ?? 0 } ?? 0
        let relative = CarliDate.dayTitle(next)
        return days <= 1 ? "\(relative) · \(rule.account.name)" : "\(relative) · en \(days) días · \(rule.account.name)"
    }

    @ViewBuilder
    private var emptyState: some View {
        switch tab {
        case .all:
            ContentUnavailableView {
                Label("Sin recurrentes", systemImage: "repeat")
            } description: {
                Text("Apunta la nómina, el alquiler o el gimnasio una vez y carli los registrará solos.")
            } actions: {
                Button("Nuevo recurrente") { form = .new(subscription: false) }.buttonStyle(.glass)
            }
        case .subscriptions:
            ContentUnavailableView {
                Label("Sin suscripciones", systemImage: "repeat")
            } description: {
                Text("Marca como suscripción Netflix, Spotify o el gimnasio para ver cuánto te cuestan al año.")
            } actions: {
                Button("Nueva suscripción") { form = .new(subscription: true) }.buttonStyle(.glass)
            }
        case .pending:
            ContentUnavailableView("Nada por confirmar", systemImage: "checkmark.circle",
                                   description: Text("Los recurrentes con confirmación aparecerán aquí cuando toque el cargo."))
        case .cancelled:
            ContentUnavailableView("Sin cancelados", systemImage: "xmark.circle",
                                   description: Text("Las suscripciones que canceles quedan aquí por si las reactivas."))
        }
    }
}

enum RecurringFormTarget: Identifiable {
    case new(subscription: Bool)
    case edit(RecurringRule)

    var id: String {
        switch self {
        case .new(let subscription): "new-\(subscription)"
        case .edit(let rule): rule.id
        }
    }
}

struct RecurringRuleForm: View {
    enum Preset: String, CaseIterable, Identifiable {
        case weekly = "Semanal", monthly = "Mensual", quarterly = "Trimestral", yearly = "Anual"
        case everyDays = "Cada N días", everyMonths = "Cada N meses"
        var id: String { rawValue }
        var custom: Bool { self == .everyDays || self == .everyMonths }
    }

    let model: RecurringModel
    let target: RecurringFormTarget
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind = "expense"
    @State private var amountText = ""
    @State private var payee = ""
    @State private var accountId: String?
    @State private var categoryId: String?
    @State private var preset: Preset = .monthly
    @State private var interval = 2
    @State private var startDate = Date.now
    @State private var hasEnd = false
    @State private var endDate = Date.now
    @State private var mode = "auto"
    @State private var remindDays = 2
    @State private var isSubscription = false
    @State private var accounts: [FinanceAccount] = []
    @State private var categories: [FinanceCategory] = []
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var error: String?

    private var editing: RecurringRule? {
        if case .edit(let rule) = target { rule } else { nil }
    }

    private var amount: Int? { Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }

    private var valid: Bool {
        amount != nil && !payee.trimmingCharacters(in: .whitespaces).isEmpty && accountId != nil
            && (!hasEnd || endDate >= startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        Text("Gasto").tag("expense")
                        Text("Ingreso").tag("income")
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Importe")
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("€").foregroundStyle(CarliColor.text3)
                    }
                    TextField("Nombre (comercio o concepto)", text: $payee)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    Picker("Cuenta", selection: $accountId) {
                        if accountId == nil { Text("Elegir").tag(String?.none) }
                        ForEach(accounts.filter { !$0.isArchived || $0.id == accountId }) { account in
                            Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
                        }
                    }
                    NavigationLink {
                        CategoryPickerView(categories: categories, kind: kind, selection: $categoryId)
                    } label: {
                        LabeledContent("Categoría") {
                            Text(categoryLabel ?? "Sin categoría").foregroundStyle(CarliColor.text2)
                        }
                    }
                }
                Section {
                    Picker("Frecuencia", selection: $preset) {
                        ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if preset.custom {
                        Stepper(preset == .everyDays ? "Cada \(interval) días" : "Cada \(interval) meses", value: $interval, in: 1...365)
                    }
                    DatePicker("Primer cargo", selection: $startDate, displayedComponents: .date)
                    Toggle("Tiene fecha de fin", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Último cargo", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section {
                    Picker("Al llegar la fecha", selection: $mode) {
                        Text("Automático").tag("auto")
                        Text("Con confirmación").tag("confirm")
                    }
                    Stepper("Avisarme \(RecurringView.reminderLabel(remindDays).lowercased())", value: $remindDays, in: 0...30)
                    Toggle("Es una suscripción", isOn: $isSubscription)
                } footer: {
                    Text(mode == "auto" ? "Se apunta solo el día del cargo." : "El día del cargo queda pendiente hasta que lo confirmes con el importe real.")
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
                if editing != nil {
                    Section {
                        Button("Eliminar", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Nuevo recurrente" : "Editar recurrente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Guardar", role: .confirm) { save() }.disabled(!valid)
                    }
                }
            }
            .confirmationDialog("¿Eliminar \(editing?.name ?? "")?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { delete() }
            } message: {
                Text("Se borrarán también los cargos pendientes de confirmar. Los movimientos ya registrados se mantienen.")
            }
        }
        .task { await load() }
    }

    private var categoryLabel: String? {
        guard let categoryId else { return nil }
        for parent in categories {
            if parent.id == categoryId { return parent.name }
            if let child = parent.children?.first(where: { $0.id == categoryId }) { return "\(parent.name) › \(child.name)" }
        }
        return editing?.category?.label
    }

    private func load() async {
        if let rule = editing, amountText.isEmpty {
            kind = rule.kind == "income" ? "income" : "expense"
            amountText = Money.input(abs(rule.amountCents))
            payee = rule.payee ?? rule.name
            accountId = rule.accountId
            categoryId = rule.categoryId
            let every = rule.interval ?? 1
            preset = switch rule.frequency {
            case "daily": .everyDays
            case "weekly": .weekly
            case "yearly": .yearly
            default: every == 1 ? .monthly : every == 3 ? .quarterly : .everyMonths
            }
            interval = every > 1 ? every : 2
            startDate = CarliDate.day(rule.startDate) ?? .now
            if let end = rule.endDate.flatMap(CarliDate.day) { hasEnd = true; endDate = end }
            mode = rule.mode ?? "auto"
            remindDays = rule.remindDaysBefore ?? 2
            isSubscription = rule.isSubscription == true
        } else if case .new(let subscription) = target {
            isSubscription = subscription
        }
        if let page: AccountsPage = try? await model.api.get("v1/finance/accounts", query: ["include_archived": "1"]) {
            accounts = page.data
            if accountId == nil {
                let active = page.data.filter { !$0.isArchived }
                accountId = (active.first { $0.type == "checking" } ?? active.first)?.id
            }
        }
        if let envelope: DataEnvelope<[FinanceCategory]> = try? await model.api.get("v1/finance/categories") {
            categories = envelope.data
        }
        if !hasEnd, let next = CarliDate.calendar.date(byAdding: .month, value: 12, to: startDate) { endDate = next }
    }

    private struct Payload: Encodable {
        var kind: String
        var amountCents: Int
        var payee: String
        var accountId: String
        var categoryId: String?
        var frequency: String
        var interval: Int
        var startDate: String
        var endDate: String?
        var mode: String
        var remindDaysBefore: Int
        var isSubscription: Bool

        private enum CodingKeys: String, CodingKey {
            case kind, amountCents, payee, accountId, categoryId, frequency, interval, startDate, endDate, mode, remindDaysBefore, isSubscription
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(kind, forKey: .kind)
            try c.encode(amountCents, forKey: .amountCents)
            try c.encode(payee, forKey: .payee)
            try c.encode(accountId, forKey: .accountId)
            try c.encode(categoryId, forKey: .categoryId)
            try c.encode(frequency, forKey: .frequency)
            try c.encode(interval, forKey: .interval)
            try c.encode(startDate, forKey: .startDate)
            try c.encode(endDate, forKey: .endDate)
            try c.encode(mode, forKey: .mode)
            try c.encode(remindDaysBefore, forKey: .remindDaysBefore)
            try c.encode(isSubscription, forKey: .isSubscription)
        }
    }

    private func save() {
        guard let amount, let accountId else { return }
        let schedule: (String, Int) = switch preset {
        case .weekly: ("weekly", 1)
        case .monthly: ("monthly", 1)
        case .quarterly: ("monthly", 3)
        case .yearly: ("yearly", 1)
        case .everyDays: ("daily", interval)
        case .everyMonths: ("monthly", interval)
        }
        let payload = Payload(kind: kind, amountCents: kind == "expense" ? -amount : amount,
                              payee: payee.trimmingCharacters(in: .whitespaces), accountId: accountId, categoryId: categoryId,
                              frequency: schedule.0, interval: schedule.1, startDate: CarliDate.isoDay(startDate),
                              endDate: hasEnd ? CarliDate.isoDay(endDate) : nil, mode: mode, remindDaysBefore: remindDays,
                              isSubscription: isSubscription)
        saving = true
        error = nil
        Task {
            do {
                if let editing {
                    let _: Empty = try await model.api.patch("v1/finance/recurring-rules/\(editing.id)", body: payload)
                } else {
                    let _: Empty = try await model.api.post("v1/finance/recurring-rules", body: payload)
                }
                NotificationCenter.default.post(name: .financeChanged, object: nil)
                onSaved(editing == nil ? "Recurrente creado" : "Recurrente actualizado")
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "No se ha podido guardar el recurrente.")
            }
            saving = false
        }
    }

    private func delete() {
        guard let editing else { return }
        Task {
            do {
                try await model.delete(editing)
                onSaved("Recurrente eliminado")
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "No se ha podido eliminar el recurrente.")
            }
        }
    }
}

/// Confirms a pending charge (or registers the next one now) with the real amount and date.
struct ConfirmOccurrenceView: View {
    let api: APIClient
    let rule: RecurringRule
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var updateRule = true
    @State private var saving = false
    @State private var error: String?

    private var expected: Int { abs(rule.pendingTransaction?.amountCents ?? rule.amountCents) }
    private var amount: Int? { Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }

    private var priceChange: (up: Bool, difference: Int, percent: Int)? {
        let base = abs(rule.amountCents)
        guard let amount, amount != base else { return nil }
        let difference = amount - base
        return (difference > 0, abs(difference), base == 0 ? 0 : Int((Double(abs(difference)) / Double(base) * 100).rounded()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Importe")
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("€").foregroundStyle(CarliColor.text3)
                    }
                    DatePicker("Fecha del cargo", selection: $date, displayedComponents: .date)
                } footer: {
                    Text("\(rule.frequencyLabel) · \(rule.account.name) · previsto \(Money.format(expected))")
                }
                if let change = priceChange {
                    Section {
                        Label("\(change.up ? "Sube" : "Baja") \(Money.format(change.difference)) (\(change.percent) %) respecto a lo previsto",
                              systemImage: change.up ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(CarliColor.warning)
                        Toggle("Actualizar el importe de los próximos cargos", isOn: $updateRule)
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle("Confirmar \(rule.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Confirmar", role: .confirm) { confirm() }.disabled(amount == nil)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            amountText = Money.input(expected)
            date = (rule.pendingTransaction?.date ?? rule.nextOccurrence).flatMap(CarliDate.day) ?? .now
        }
    }

    private struct Payload: Encodable {
        var amountCents: Int
        var date: String
        var updateRuleAmount: Bool
    }

    private struct Result: Decodable {
        struct Data: Decodable {
            struct Transaction: Decodable { var amountCents: Int }
            var transaction: Transaction
            var priceChanged: Bool?
        }
        var data: Data
    }

    private func confirm() {
        guard let amount else { return }
        let update = priceChange != nil && updateRule
        saving = true
        error = nil
        Task {
            do {
                let result: Result = try await api.post("v1/finance/recurring-rules/\(rule.id)/confirm",
                                                        body: Payload(amountCents: amount, date: CarliDate.isoDay(date), updateRuleAmount: update))
                NotificationCenter.default.post(name: .financeChanged, object: nil)
                let suffix = result.data.priceChanged == true && update ? " · importe actualizado" : ""
                onDone("\(rule.name) confirmado: \(Money.format(result.data.transaction.amountCents, .signed))\(suffix)")
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "No se ha podido confirmar el cargo.")
            }
            saving = false
        }
    }
}
