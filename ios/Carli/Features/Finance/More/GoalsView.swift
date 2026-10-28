import SwiftUI

struct SavingsGoal: Decodable, Identifiable, Equatable {
    var id: String
    var name: String
    var targetCents: Int
    var targetDate: String?
    var accountId: String?
    var account: AccountRef?
    var icon: String?
    var achieved: Bool?
    var savedCents: Int
    var remainingCents: Int
    var progressBp: Int?
    var monthsLeft: Int?
    var monthlyNeededCents: Int?
    var contributionsCount: Int?

    static let icons: [(String, String)] = [
        ("piggy-bank", "Hucha"), ("shield", "Emergencias"), ("plane", "Viaje"), ("laptop", "Tecnología"),
        ("house", "Casa"), ("car", "Coche"), ("gift", "Regalo"), ("graduation-cap", "Estudios"),
        ("heart", "Salud"), ("smartphone", "Móvil"), ("tree-palm", "Vacaciones"), ("target", "Otro"),
    ]

    var isAchieved: Bool { achieved == true }
    var percent: Int { (progressBp ?? 0) / 100 }
    var ratio: Double { Double(progressBp ?? 0) / 10000 }
    var iconName: String { icon ?? "piggy-bank" }
    var target: Date? { targetDate.flatMap(CarliDate.day) }

    var targetMonthLabel: String? {
        guard let target else { return nil }
        let parts = CarliDate.calendar.dateComponents([.month, .year], from: target)
        return "\(CarliDate.monthsShort[(parts.month ?? 1) - 1]) \(parts.year ?? 0)"
    }

    var remainingLabel: String { remainingCents == 0 ? "Nada, ¡lo tienes!" : Money.format(remainingCents) }

    var monthlyLabel: String {
        if isAchieved || remainingCents == 0 { return "—" }
        if let monthly = monthlyNeededCents, monthly > 0 { return "\(Money.format(monthly))/mes" }
        return "Sin fecha límite"
    }

    var monthsLeftLabel: String? {
        guard let monthsLeft, !isAchieved else { return nil }
        return monthsLeft == 1 ? "Durante 1 mes" : "Durante \(monthsLeft) meses"
    }
}

struct GoalContribution: Decodable, Identifiable, Equatable {
    var id: String
    var goalId: String
    var amountCents: Int
    var date: String
    var note: String?
}

/// Every field goes out so clearing the date or the account sticks.
struct GoalInput: Encodable {
    var name: String
    var targetCents: Int
    var targetDate: String?
    var accountId: String?
    var icon: String

    private enum CodingKeys: String, CodingKey { case name, targetCents, targetDate, accountId, icon }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(targetCents, forKey: .targetCents)
        try container.encode(targetDate, forKey: .targetDate)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(icon, forKey: .icon)
    }
}

struct ContributionInput: Encodable {
    var amountCents: Int
    var date: String
    var note: String?

    private enum CodingKeys: String, CodingKey { case amountCents, date, note }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amountCents, forKey: .amountCents)
        try container.encode(date, forKey: .date)
        try container.encode(note, forKey: .note)
    }
}

struct GoalRoute: Hashable { var id: String }

@Observable
final class GoalsModel {
    enum State { case loading, loaded, failed(String) }

    var state: State = .loading
    var goals: [SavingsGoal] = []
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            let envelope: DataEnvelope<[SavingsGoal]> = try await api.get("v1/finance/goals")
            // Achieved goals sink to the bottom; otherwise keep the server order.
            goals = envelope.data.enumerated().sorted {
                ($0.element.isAchieved ? 1 : 0, $0.offset) < ($1.element.isAchieved ? 1 : 0, $1.offset)
            }.map(\.element)
            state = .loaded
        } catch {
            if goals.isEmpty { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
    }
}

/// Más › Objetivos: a card per savings goal with its progress and the monthly effort.
struct GoalsView: View {
    @State var model: GoalsModel
    @State private var form: GoalFormTarget?
    @State private var contributing: SavingsGoal?
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                switch model.state {
                case .loading:
                    ForEach(0..<3, id: \.self) { _ in CarliCard { SkeletonBar(width: 260, height: 70) } }
                case .failed(let message):
                    CardMessage(title: "No se han podido cargar los objetivos", symbol: "exclamationmark.circle",
                                message: message, action: "Reintentar") { Task { await model.load() } }
                case .loaded:
                    if model.goals.isEmpty {
                        CarliCard {
                            ContentUnavailableView {
                                Label("Aún no tienes objetivos", systemImage: "target")
                            } description: {
                                Text("Ponle nombre y cifra a lo que quieres conseguir y te diremos cuánto apartar cada mes.")
                            } actions: {
                                Button("Nuevo objetivo") { form = .new }.buttonStyle(.glassProminent)
                            }
                        }
                    } else {
                        ForEach(model.goals) { goal in
                            NavigationLink(value: GoalRoute(id: goal.id)) {
                                GoalCard(goal: goal) { contributing = goal }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle("Objetivos de ahorro")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuevo objetivo", systemImage: "plus") { form = .new }
            }
        }
        .refreshable { await model.load() }
        .task { if model.goals.isEmpty { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await model.load() } }
        .sheet(item: $form) { target in
            GoalFormView(api: model.api, goal: target.goal) { toast = $0 }
        }
        .sheet(item: $contributing) { goal in
            ContributionView(api: model.api, goal: goal) { toast = $0 }
        }
        .carliToast($toast)
    }
}

private struct GoalCard: View {
    var goal: SavingsGoal
    var contribute: () -> Void

    var body: some View {
        CarliCard {
            HStack {
                IconBubble(symbol: CarliIcon.symbol(goal.iconName), size: 36)
                Spacer()
                CarliBadge(label: "\(goal.percent) %", symbol: goal.isAchieved ? "checkmark" : nil)
            }
            Text(goal.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .padding(.top, CarliSpace.s12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.format(goal.savedCents))
                    .font(.title3.weight(.semibold))
                Text("de \(Money.format(goal.targetCents))")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
            }
            .monospacedDigit()
            .foregroundStyle(CarliColor.text)
            .padding(.top, CarliSpace.s4)
            ProgressBar(ratio: goal.ratio)
                .padding(.top, CarliSpace.s12)
            Text(meta)
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
                .padding(.top, CarliSpace.s8)
            if let account = goal.account {
                Label("Vinculado a la cuenta \(account.name)", systemImage: "link")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text3)
                    .padding(.top, CarliSpace.s4)
            } else if !goal.isAchieved {
                Button("Aportar", systemImage: "plus", action: contribute)
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .padding(.top, CarliSpace.s12)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        if goal.isAchieved { return "Objetivo conseguido" }
        guard let month = goal.targetMonthLabel else { return "Sin fecha límite" }
        if let monthly = goal.monthlyNeededCents, monthly > 0 { return "Meta: \(month) · aporta \(Money.format(monthly))/mes" }
        return "Meta: \(month)"
    }
}

/// One goal: progress, what is left, the monthly effort and its contributions.
struct GoalDetailView: View {
    let api: APIClient
    let goalId: String

    @Environment(\.dismiss) private var dismiss
    @State private var goal: SavingsGoal?
    @State private var contributions: [GoalContribution]?
    @State private var failed = false
    @State private var editing = false
    @State private var contributing = false
    @State private var toast: String?
    @State private var undo: GoalContribution?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                if let goal {
                    content(goal)
                } else if failed {
                    CardMessage(title: "No encontramos este objetivo", symbol: "exclamationmark.circle",
                                message: "Puede que se haya eliminado.", action: "Volver a objetivos") { dismiss() }
                } else {
                    CarliCard { SkeletonBar(width: 260, height: 90) }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle(goal?.name ?? "Objetivo")
        .toolbar {
            if let goal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Editar objetivo", systemImage: "pencil") { editing = true }
                }
                if goal.accountId == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Aportar", systemImage: "plus") { contributing = true }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $editing) {
            if let goal {
                GoalFormView(api: api, goal: goal, onDeleted: { dismiss() }) { toast = $0; Task { await load() } }
            }
        }
        .sheet(isPresented: $contributing) {
            if let goal {
                ContributionView(api: api, goal: goal) { toast = $0; Task { await load() } }
            }
        }
        .carliToast($toast)
        .overlay(alignment: .bottom) {
            if let undo {
                UndoBar(text: "Aportación borrada") {
                    self.undo = nil
                    Task { await restore(undo) }
                }
                .task(id: undo.id) {
                    try? await Task.sleep(for: .seconds(5))
                    if self.undo?.id == undo.id { self.undo = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ goal: SavingsGoal) -> some View {
        CarliCard {
            HStack(spacing: CarliSpace.s8) {
                IconBubble(symbol: CarliIcon.symbol(goal.iconName), size: 36)
                Text(goal.account.map { "Saldo de \($0.name)" } ?? "Ahorrado")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                Spacer()
                CarliBadge(label: goal.isAchieved ? "Conseguido" : "\(goal.percent) %", symbol: goal.isAchieved ? "checkmark" : nil)
            }
            HStack(alignment: .firstTextBaseline, spacing: CarliSpace.s8) {
                Text(Money.format(goal.savedCents))
                    .font(.system(size: 34, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("de \(Money.format(goal.targetCents))")
                    .foregroundStyle(CarliColor.text2)
            }
            .monospacedDigit()
            .foregroundStyle(CarliColor.text)
            .padding(.top, CarliSpace.s12)
            ProgressBar(ratio: goal.ratio).padding(.top, CarliSpace.s12)
            if let account = goal.account {
                Label("El progreso es el saldo de \(account.name). Para aportar, haz una transferencia a esa cuenta.",
                      systemImage: "link")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text3)
                    .padding(.top, CarliSpace.s12)
                NavigationLink(value: AccountLink(id: account.id)) {
                    Label("Ver cuenta", systemImage: "building.columns")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .padding(.top, CarliSpace.s12)
            }
        }

        Grid(horizontalSpacing: CarliSpace.s12) {
            GridRow {
                StatCard(label: "Te falta", value: goal.remainingLabel,
                         valueColor: goal.isAchieved ? CarliColor.positive : CarliColor.text)
                StatCard(label: "Aportación mensual", value: goal.monthlyLabel, note: goal.monthsLeftLabel)
            }
        }
        StatCard(label: "Fecha objetivo", value: goal.targetMonthLabel ?? "Sin fecha",
                 note: goal.target.map { CarliDate.long($0) } ?? "Ahorra a tu ritmo")

        if goal.accountId == nil {
            contributionsCard(goal)
        }
    }

    private func contributionsCard(_ goal: SavingsGoal) -> some View {
        CarliCard(padding: 0) {
            Text("Aportaciones")
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .accessibilityAddTraits(.isHeader)
                .padding([.horizontal, .top], CarliSpace.s16)
                .padding(.bottom, CarliSpace.s8)
            if let contributions {
                if contributions.isEmpty {
                    ContentUnavailableView {
                        Label("Sin aportaciones todavía", systemImage: "dollarsign.circle")
                    } description: {
                        Text("Cada vez que apartes dinero para este objetivo, regístralo aquí.")
                    } actions: {
                        Button("Aportar") { contributing = true }.buttonStyle(.glass)
                    }
                } else {
                    ForEach(Array(contributions.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 68) }
                        HStack(spacing: CarliSpace.s12) {
                            IconBubble(symbol: item.amountCents > 0 ? "plus" : "minus")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.note ?? (item.amountCents > 0 ? "Aportación" : "Retirada"))
                                    .foregroundStyle(CarliColor.text)
                                Text(CarliDate.dayTitle(item.date))
                                    .font(.footnote)
                                    .foregroundStyle(CarliColor.text2)
                            }
                            Spacer()
                            Text(Money.format(item.amountCents, .signed))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(item.amountCents > 0 ? CarliColor.positive : CarliColor.text)
                            Button("Borrar aportación", systemImage: "trash") { Task { await remove(item) } }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, CarliSpace.s16)
                        .padding(.vertical, CarliSpace.s8)
                    }
                }
            } else {
                SkeletonBar(width: 240, height: 16).padding(CarliSpace.s16)
            }
        }
        .padding(.bottom, CarliSpace.s8)
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<SavingsGoal> = try await api.get("v1/finance/goals/\(goalId)")
            goal = envelope.data
            if envelope.data.accountId == nil {
                let list: DataEnvelope<[GoalContribution]> = try await api.get("v1/finance/goals/\(goalId)/contributions")
                contributions = list.data.sorted { $0.date > $1.date }
            }
        } catch {
            if goal == nil { failed = true }
        }
    }

    private func remove(_ item: GoalContribution) async {
        do {
            try await api.delete("v1/finance/goals/\(goalId)/contributions/\(item.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            undo = item
            await load()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar la aportación.")
        }
    }

    private func restore(_ item: GoalContribution) async {
        do {
            let _: Empty = try await api.post("v1/finance/goals/\(goalId)/contributions",
                                              body: ContributionInput(amountCents: item.amountCents, date: item.date, note: item.note))
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            await load()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido registrar la aportación.")
        }
    }
}

enum GoalFormTarget: Identifiable {
    case new
    case edit(SavingsGoal)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let goal): goal.id
        }
    }

    var goal: SavingsGoal? {
        if case .edit(let goal) = self { return goal }
        return nil
    }
}

/// New / edit goal: target, name, icon, optional date and how progress is measured.
struct GoalFormView: View {
    let api: APIClient
    let goal: SavingsGoal?
    var onDeleted: (() -> Void)?
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetText = ""
    @State private var icon = "piggy-bank"
    @State private var hasDate = false
    @State private var targetDate = CarliDate.calendar.date(byAdding: .month, value: 12, to: .now) ?? .now
    @State private var fromAccount = false
    @State private var accountId: String?
    @State private var accounts: [FinanceAccount] = []
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var error: String?

    init(api: APIClient, goal: SavingsGoal?, onDeleted: (() -> Void)? = nil, onSaved: @escaping (String) -> Void) {
        self.api = api
        self.goal = goal
        self.onDeleted = onDeleted
        self.onSaved = onSaved
        if let goal {
            _name = State(initialValue: goal.name)
            _targetText = State(initialValue: Money.input(goal.targetCents))
            _icon = State(initialValue: goal.iconName)
            _hasDate = State(initialValue: goal.target != nil)
            if let date = goal.target { _targetDate = State(initialValue: date) }
            _fromAccount = State(initialValue: goal.accountId != nil)
            _accountId = State(initialValue: goal.accountId)
        }
    }

    /// Savings accounts first; a linked goal defaults to the first of them.
    private var choices: [FinanceAccount] {
        let active = accounts.filter { !$0.isArchived }
        return active.filter { $0.type == "savings" } + active.filter { $0.type != "savings" }
    }

    private var effectiveAccountId: String? { accountId ?? choices.first(where: { $0.type == "savings" })?.id }
    private var target: Int? { Money.parse(targetText) }

    private var canSave: Bool {
        !saving && !name.trimmingCharacters(in: .whitespaces).isEmpty && (target ?? 0) > 0
            && (!fromAccount || effectiveAccountId != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountRow(title: "Importe meta", text: $targetText)
                    TextField("Nombre (Fondo de emergencia, Viaje a Japón…)", text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Icono") {
                    IconGrid(icons: SavingsGoal.icons.map(\.0), selection: $icon)
                }
                Section {
                    Toggle("Tiene fecha objetivo", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Fecha objetivo", selection: $targetDate, displayedComponents: .date)
                    }
                } footer: {
                    if hasDate { Text("Calculamos cuánto aportar cada mes para llegar a tiempo.") }
                }
                Section {
                    Picker("Cómo se mide el progreso", selection: $fromAccount) {
                        Text("Aportaciones").tag(false)
                        Text("Saldo de una cuenta").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if fromAccount {
                        Picker("Cuenta", selection: Binding(get: { effectiveAccountId }, set: { accountId = $0 })) {
                            if effectiveAccountId == nil { Text("Elige una cuenta").tag(String?.none) }
                            ForEach(choices) { account in
                                Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
                            }
                        }
                    }
                } header: {
                    Text("Cómo se mide el progreso")
                } footer: {
                    Text(fromAccount ? "El progreso es el saldo de la cuenta: ahorra con transferencias a ella."
                         : "Registra aportaciones a mano cuando apartes dinero.")
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
                if goal != nil {
                    Section {
                        Button("Eliminar objetivo", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(goal == nil ? "Nuevo objetivo" : "Editar objetivo")
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
            .confirmationDialog("¿Eliminar \(goal?.name ?? "el objetivo")?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { Task { await delete() } }
            } message: {
                Text("Se borrará el objetivo y su historial de aportaciones. Tus cuentas y movimientos no cambian.")
            }
            .task {
                if let page: AccountsPage = try? await api.get("v1/finance/accounts") { accounts = page.data }
            }
        }
    }

    private func save() async {
        guard canSave, let target else { return }
        saving = true
        error = nil
        defer { saving = false }
        let body = GoalInput(name: name.trimmingCharacters(in: .whitespaces), targetCents: target,
                             targetDate: hasDate ? CarliDate.isoDay(targetDate) : nil,
                             accountId: fromAccount ? effectiveAccountId : nil, icon: icon)
        do {
            if let goal {
                let _: Empty = try await api.patch("v1/finance/goals/\(goal.id)", body: body)
            } else {
                let _: Empty = try await api.post("v1/finance/goals", body: body)
            }
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            onSaved(goal == nil ? "Objetivo creado" : "Objetivo actualizado")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el objetivo.")
        }
    }

    private func delete() async {
        guard let goal else { return }
        do {
            try await api.delete("v1/finance/goals/\(goal.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            onSaved("\(goal.name) eliminado")
            dismiss()
            onDeleted?()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido eliminar el objetivo.")
        }
    }
}

/// Aportar / Retirar on a manual goal.
struct ContributionView: View {
    let api: APIClient
    let goal: SavingsGoal
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var withdraw = false
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var note = ""
    @State private var saving = false
    @State private var error: String?

    private struct Result: Decodable {
        struct Meta: Decodable { var goal: SavingsGoal }
        var meta: Meta
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Dirección", selection: $withdraw) {
                        Text("Aportar").tag(false)
                        Text("Retirar").tag(true)
                    }
                    .pickerStyle(.segmented)
                    AmountRow(title: "Importe", text: $amountText)
                    DatePicker("Fecha", selection: $date, in: ...Date.now, displayedComponents: .date)
                    TextField("Nota (opcional)", text: $note)
                } footer: {
                    Text("\(goal.name) · \(Money.format(goal.savedCents)) de \(Money.format(goal.targetCents))")
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle(withdraw ? "Retirar" : "Aportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button(withdraw ? "Retirar" : "Aportar", role: .confirm) { Task { await save() } }
                            .disabled((Money.parse(amountText) ?? 0) <= 0)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if let monthly = goal.monthlyNeededCents, monthly > 0 { amountText = Money.input(monthly) }
        }
    }

    private func save() async {
        guard let magnitude = Money.parse(amountText), magnitude > 0 else {
            error = "Indica un importe mayor que cero."
            return
        }
        let amount = withdraw ? -magnitude : magnitude
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        saving = true
        error = nil
        defer { saving = false }
        do {
            let result: Result = try await api.post("v1/finance/goals/\(goal.id)/contributions",
                                                    body: ContributionInput(amountCents: amount, date: CarliDate.isoDay(date),
                                                                            note: trimmed.isEmpty ? nil : trimmed))
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            let after = result.meta.goal
            onDone(after.isAchieved && !goal.isAchieved ? "¡Objetivo conseguido! \(after.name) al 100 %"
                   : "\(Money.format(amount, .signed)) · \(after.name) al \(after.percent) %")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido registrar la aportación.")
        }
    }
}
