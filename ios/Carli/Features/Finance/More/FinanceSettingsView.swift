import SwiftUI

@Observable
final class FinanceSettingsModel {
    var settings: FinanceSettingsFull?
    var accounts: [FinanceAccount] = []
    var incomeCategories: [FinanceCategory] = []
    var periods: [FinancePeriod] = []
    var failed: String?
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            let envelope: DataEnvelope<FinanceSettingsFull> = try await api.get("v1/finance/settings")
            settings = envelope.data
            failed = nil
        } catch {
            if settings == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
        if let page: AccountsPage = try? await api.get("v1/finance/accounts") { accounts = page.data.filter { !$0.isArchived } }
        await loadCategories()
        await loadPeriods()
    }

    func loadCategories() async {
        if let list: DataEnvelope<[FinanceCategory]> = try? await api.get("v1/finance/categories") {
            incomeCategories = list.data.filter { $0.kind == "income" && !$0.isArchived }
        }
    }

    func loadPeriods() async {
        if let list: DataEnvelope<[FinancePeriod]> = try? await api.get("v1/finance/periods") { periods = list.data }
    }
}

/// Body for PATCH settings: every field, a null account meaning "the last one used".
struct FinanceSettingsInput: Encodable {
    var defaultAccountId: String?
    var budgetWarningThreshold: Int
    var remindDaysBefore: Int
    var periodMode: String
    var periodMinDays: Int
    var savingsTargetPercent: Int

    private enum CodingKeys: String, CodingKey {
        case defaultAccountId, budgetWarningThreshold, remindDaysBefore, periodMode, periodMinDays, savingsTargetPercent
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultAccountId, forKey: .defaultAccountId)
        try container.encode(budgetWarningThreshold, forKey: .budgetWarningThreshold)
        try container.encode(remindDaysBefore, forKey: .remindDaysBefore)
        try container.encode(periodMode, forKey: .periodMode)
        try container.encode(periodMinDays, forKey: .periodMinDays)
        try container.encode(savingsTargetPercent, forKey: .savingsTargetPercent)
    }
}

/// Finanzas › Ajustes de Finanzas: general settings, banks, categories that open a period and periods.
struct FinanceSettingsView: View {
    @State var model: FinanceSettingsModel

    @State private var accountId: String?
    @State private var threshold = 80
    @State private var remind = 3
    @State private var savingsTarget = 20
    @State private var payroll = true
    @State private var minDays = 20
    @State private var saving = false
    @State private var pendingCategory: Set<String> = []
    @State private var periodSheet: PeriodSheet?
    @State private var toast: String?

    enum PeriodSheet: Identifiable {
        case open
        case move(FinancePeriod)

        var id: String {
            switch self {
            case .open: "open"
            case .move(let period): period.id
            }
        }
    }

    private var dirty: Bool {
        guard let settings = model.settings else { return false }
        return accountId != settings.defaultAccountId || threshold != (settings.budgetWarningThreshold ?? 80)
            || remind != (settings.remindDaysBefore ?? 3) || savingsTarget != (settings.savingsTargetPercent ?? 20)
            || payroll != (settings.periodMode != "calendar") || minDays != (settings.periodMinDays ?? 20)
    }

    var body: some View {
        Form {
            if let failed = model.failed {
                Section {
                    Text(failed).foregroundStyle(CarliColor.negative)
                    Button("Reintentar") { Task { await model.load() } }
                }
            }
            if model.settings != nil {
                generalSection
            }

            Section {
                NavigationLink(value: BanksRoute()) {
                    Label("Bancos y reglas", systemImage: "building.columns")
                }
            } header: {
                Text("Bancos")
            } footer: {
                Text("Importa movimientos de Revolut, BBVA o MyInvestor y gestiona las reglas de categorización.")
            }

            Section {
                if model.incomeCategories.isEmpty {
                    Text("No tienes categorías de ingreso.").foregroundStyle(CarliColor.text3)
                }
                ForEach(model.incomeCategories) { category in
                    Toggle(isOn: Binding(get: { category.opensPeriod == true }, set: { value in
                        Task { await setOpensPeriod(category, value) }
                    })) {
                        Label(category.name, systemImage: CarliIcon.symbol(category.icon ?? "tag"))
                    }
                    .disabled(pendingCategory.contains(category.id))
                }
            } header: {
                Text("Categorías que abren periodo")
            } footer: {
                Text("Al registrar un ingreso de estas categorías empieza un periodo nuevo.")
            }

            Section {
                ForEach(model.periods.prefix(6)) { period in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(period.name).foregroundStyle(CarliColor.text)
                            Text(period.subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                        Spacer()
                        CarliBadge(label: period.isCurrent == true ? "En curso" : period.openedByLabel)
                        Button("Mover el inicio del \(period.name)", systemImage: "pencil") { periodSheet = .move(period) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                }
            } header: {
                HStack {
                    Text("Periodos")
                    Spacer()
                    Button("Abrir periodo", systemImage: "calendar.badge.plus") { periodSheet = .open }
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }
        }
        .navigationTitle("Ajustes de Finanzas")
        .refreshable { await model.load() }
        .task {
            if model.settings == nil {
                await model.load()
                reset()
            }
        }
        .sheet(item: $periodSheet) { sheet in
            PeriodDateView(api: model.api, sheet: sheet) { message in
                toast = message
                Task { await model.loadPeriods() }
            }
        }
        .carliToast($toast)
    }

    private var generalSection: some View {
        Section {
            Picker("Cuenta por defecto", selection: $accountId) {
                Text("La última usada").tag(String?.none)
                ForEach(model.accounts) { account in
                    Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
                }
            }
            Stepper("Aviso de presupuesto: \(threshold) %", value: $threshold, in: 1...100, step: 5)
            Stepper("Avisar de cargos: \(remind == 0 ? "el mismo día" : remind == 1 ? "1 día antes" : "\(remind) días antes")",
                    value: $remind, in: 0...30)
            Stepper("Objetivo de ahorro: \(savingsTarget) %", value: $savingsTarget, in: 1...100)
            Picker("Periodo financiero", selection: $payroll) {
                Text("De nómina a nómina").tag(true)
                Text("Mes natural").tag(false)
            }
            if payroll {
                Stepper("Días mínimos entre nóminas: \(minDays)", value: $minDays, in: 1...60)
            }
            HStack {
                Spacer()
                if saving { ProgressView() } else {
                    Button("Guardar") { Task { await save() } }
                        .buttonStyle(.glassProminent)
                        .tint(CarliColor.primary)
                        .foregroundStyle(CarliColor.onPrimary)
                        .disabled(!dirty)
                }
            }
        } header: {
            Text("General")
        } footer: {
            Text("""
            Sin cuenta por defecto se usa la última con la que apuntaste un movimiento. \
            El aviso de presupuesto salta al llegar al porcentaje y al superar el 100 %. \
            El objetivo de ahorro llena el anillo de Ahorro del resumen. \
            \(payroll ? "Cada periodo empieza el día que registras la nómina; una paga extra antes de los días mínimos no abre periodo nuevo." : "Cada periodo va del día 1 al último día del mes.")
            """)
        }
    }

    private func reset() {
        guard let settings = model.settings else { return }
        accountId = settings.defaultAccountId
        threshold = settings.budgetWarningThreshold ?? 80
        remind = settings.remindDaysBefore ?? 3
        savingsTarget = settings.savingsTargetPercent ?? 20
        payroll = settings.periodMode != "calendar"
        minDays = settings.periodMinDays ?? 20
    }

    private struct SaveResult: Decodable {
        struct Meta: Decodable { var periodsChanged: Bool? }
        var data: FinanceSettingsFull
        var meta: Meta?
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let body = FinanceSettingsInput(defaultAccountId: accountId, budgetWarningThreshold: threshold, remindDaysBefore: remind,
                                        periodMode: payroll ? "payroll" : "calendar", periodMinDays: minDays,
                                        savingsTargetPercent: savingsTarget)
        do {
            let result: SaveResult = try await model.api.patch("v1/finance/settings", body: body)
            model.settings = result.data
            reset()
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            toast = result.meta?.periodsChanged == true ? "Ajustes guardados · periodos recalculados" : "Ajustes guardados"
            if result.meta?.periodsChanged == true { await model.loadPeriods() }
        } catch {
            toast = error.apiMessage(fallback: "No se han podido guardar los ajustes.")
        }
    }

    private func setOpensPeriod(_ category: FinanceCategory, _ value: Bool) async {
        pendingCategory.insert(category.id)
        defer { pendingCategory.remove(category.id) }
        do {
            let _: Empty = try await model.api.patch("v1/finance/categories/\(category.id)", body: ["opens_period": value])
            toast = value ? "\(category.name) abrirá periodo" : "\(category.name) ya no abre periodo"
            NotificationCenter.default.post(name: .financeChanged, object: nil)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido actualizar la categoría.")
        }
        await model.loadCategories()
    }
}

/// Opens a period by hand or moves a period's start.
struct PeriodDateView: View {
    let api: APIClient
    let sheet: FinanceSettingsView.PeriodSheet
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var saving = false
    @State private var error: String?

    private var latest: Date { CarliDate.calendar.date(byAdding: .day, value: 31, to: .now) ?? .now }

    private var period: FinancePeriod? {
        if case .move(let period) = sheet { return period }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha de inicio", selection: $date, in: ...latest, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                } footer: {
                    if let period {
                        Text("\(period.label ?? period.name). El periodo anterior se ajusta para terminar el día antes.")
                    } else {
                        Text("Útil si cobras en efectivo o se retrasa la nómina. El periodo anterior terminará el día antes.")
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle(period == nil ? "Abrir periodo a mano" : "Mover inicio del periodo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button(period == nil ? "Abrir periodo" : "Mover inicio", role: .confirm) { Task { await save() } }
                    }
                }
            }
        }
        .onAppear {
            if let start = period?.startDate.flatMap(CarliDate.day) { date = min(start, latest) }
        }
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        let body = ["start_date": CarliDate.isoDay(date)]
        do {
            if let period {
                if period.startDate == CarliDate.isoDay(date) { dismiss(); return }
                let _: Empty = try await api.patch("v1/finance/periods/\(period.id)", body: body)
                onDone("Inicio del periodo actualizado")
            } else {
                let created: DataEnvelope<FinancePeriod> = try await api.post("v1/finance/periods", body: body)
                onDone("Abierto el \(created.data.name.lowercased())")
            }
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: period == nil ? "No se ha podido abrir el periodo." : "No se ha podido mover el periodo.")
        }
    }
}
