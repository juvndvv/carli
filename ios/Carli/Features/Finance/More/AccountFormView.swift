import SwiftUI

@Observable
final class AccountFormModel {
    static let icons = ["landmark", "piggy-bank", "credit-card", "banknote", "wallet", "coins", "euro", "building"]

    let account: FinanceAccount?
    var name = ""
    var kind: AccountKind = .checking
    var initialBalanceText = ""
    var hasInitialDate = false
    var initialDate = Date.now
    var creditLimitText = ""
    var statementDay: Int?
    var paymentDay: Int?
    var icon: String?
    var includeInNetWorth = true
    var saving = false
    var error: String?

    private let api: APIClient

    init(api: APIClient, account: FinanceAccount?) {
        self.api = api
        self.account = account
        if let account {
            name = account.name
            kind = AccountKind(rawValue: account.type) ?? .checking
            initialBalanceText = account.initialBalanceCents.map { Money.input(abs($0)) } ?? ""
            negativeInitial = (account.initialBalanceCents ?? 0) < 0
            if let date = account.initialBalanceDate.flatMap(CarliDate.day) {
                hasInitialDate = true
                initialDate = date
            }
            creditLimitText = account.creditLimitCents.map(Money.input) ?? ""
            statementDay = account.statementDay
            paymentDay = account.paymentDay
            icon = account.icon
            includeInNetWorth = account.includeInNetWorth != false
        }
    }

    /// Cards usually start in debt; the sign toggle keeps the keypad simple.
    var negativeInitial = false

    var initialBalance: Int? {
        let trimmed = initialBalanceText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Money.parse(trimmed).map { negativeInitial ? -$0 : $0 }
    }

    var canSave: Bool {
        !saving && !name.trimmingCharacters(in: .whitespaces).isEmpty && initialBalance != nil
            && (kind != .creditCard || creditLimitText.isEmpty || Money.parse(creditLimitText) != nil)
    }

    func save() async -> Bool {
        guard canSave else { return false }
        saving = true
        error = nil
        defer { saving = false }
        let card = kind == .creditCard
        let body = AccountInput(name: name.trimmingCharacters(in: .whitespaces), type: kind.rawValue,
                                initialBalanceCents: initialBalance ?? 0,
                                initialBalanceDate: hasInitialDate ? CarliDate.isoDay(initialDate) : nil,
                                creditLimitCents: card ? Money.parse(creditLimitText) : nil,
                                statementDay: card ? statementDay : nil, paymentDay: card ? paymentDay : nil,
                                icon: icon, includeInNetWorth: includeInNetWorth)
        do {
            if let account {
                let _: Empty = try await api.patch("v1/finance/accounts/\(account.id)", body: body)
            } else {
                let _: Empty = try await api.post("v1/finance/accounts", body: body)
            }
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            return true
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar la cuenta.")
            return false
        }
    }
}

/// Every field goes out, so clearing one (a card limit, say) removes it.
struct AccountInput: Encodable {
    var name: String
    var type: String
    var initialBalanceCents: Int
    var initialBalanceDate: String?
    var creditLimitCents: Int?
    var statementDay: Int?
    var paymentDay: Int?
    var icon: String?
    var includeInNetWorth: Bool

    private enum CodingKeys: String, CodingKey {
        case name, type, initialBalanceCents, initialBalanceDate, creditLimitCents, statementDay, paymentDay, icon, includeInNetWorth
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(initialBalanceCents, forKey: .initialBalanceCents)
        try container.encode(initialBalanceDate, forKey: .initialBalanceDate)
        try container.encode(creditLimitCents, forKey: .creditLimitCents)
        try container.encode(statementDay, forKey: .statementDay)
        try container.encode(paymentDay, forKey: .paymentDay)
        try container.encode(icon, forKey: .icon)
        try container.encode(includeInNetWorth, forKey: .includeInNetWorth)
    }
}

struct AccountFormView: View {
    @State var model: AccountFormModel
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $model.name)
                        .textInputAutocapitalization(.words)
                    Picker("Tipo", selection: $model.kind) {
                        ForEach(AccountKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.symbol).tag(kind)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Saldo inicial")
                        Spacer()
                        Button(model.negativeInitial ? Money.minus : "+") { model.negativeInitial.toggle() }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .accessibilityLabel(model.negativeInitial ? "Negativo" : "Positivo")
                        TextField("0", text: $model.initialBalanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 120)
                        Text("€").foregroundStyle(CarliColor.text3)
                    }
                    Toggle("Fecha del saldo inicial", isOn: $model.hasInitialDate)
                    if model.hasInitialDate {
                        DatePicker("Desde", selection: $model.initialDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("El saldo que tenía la cuenta antes del primer movimiento que vayas a apuntar.")
                }

                if model.kind == .creditCard {
                    Section("Tarjeta") {
                        HStack {
                            Text("Límite de crédito")
                            Spacer()
                            TextField("Sin límite", text: $model.creditLimitText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .frame(maxWidth: 120)
                        }
                        dayPicker("Día de corte", selection: $model.statementDay)
                        dayPicker("Día de cargo", selection: $model.paymentDay)
                    }
                }

                Section("Icono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: CarliSpace.s12) {
                        ForEach(AccountFormModel.icons, id: \.self) { name in
                            let selected = (model.icon ?? defaultIcon) == name
                            Button {
                                model.icon = name
                            } label: {
                                Image(systemName: CarliIcon.symbol(name))
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(selected ? CarliColor.onPrimary : CarliColor.text)
                                    .background(selected ? CarliColor.primary : CarliColor.surface2, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, CarliSpace.s4)
                }

                Section {
                    Toggle("Sumar al patrimonio neto", isOn: $model.includeInNetWorth)
                }

                if let error = model.error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle(model.account == nil ? "Nueva cuenta" : "Editar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.saving {
                        ProgressView()
                    } else {
                        Button("Guardar", role: .confirm) {
                            Task {
                                if await model.save() {
                                    onSaved(model.account == nil ? "Cuenta creada" : "Cuenta actualizada")
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!model.canSave)
                    }
                }
            }
        }
    }

    private var defaultIcon: String {
        switch model.kind {
        case .checking: "landmark"
        case .savings: "piggy-bank"
        case .creditCard: "credit-card"
        case .cash: "banknote"
        }
    }

    private func dayPicker(_ title: String, selection: Binding<Int?>) -> some View {
        Picker(title, selection: selection) {
            Text("Sin definir").tag(Int?.none)
            ForEach(1...31, id: \.self) { Text("\($0)").tag(Optional($0)) }
        }
    }
}

/// Matches the app's confirmed balance with the bank's, creating an adjustment for the gap.
struct ReconcileView: View {
    let api: APIClient
    let account: FinanceAccount
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var actualText = ""
    @State private var negative = false
    @State private var date = Date.now
    @State private var saving = false
    @State private var error: String?

    private var cleared: Int { account.clearedBalanceCents ?? account.balanceCents }
    private var actual: Int? { Money.parse(actualText).map { negative ? -$0 : $0 } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Saldo confirmado en la app", value: Money.format(cleared))
                        .monospacedDigit()
                } footer: {
                    if let pending = account.pendingCents, pending != 0 {
                        Text("No cuenta los movimientos pendientes (\(Money.format(pending, .signed))).")
                    }
                }
                Section {
                    HStack {
                        Text("Saldo real")
                        Spacer()
                        Button(negative ? Money.minus : "+") { negative.toggle() }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                        TextField("0", text: $actualText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 120)
                        Text("€").foregroundStyle(CarliColor.text3)
                    }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Saldo en el banco")
                } footer: {
                    if let bank = account.bank, bank.balanceCents != nil {
                        Text("Precargado con el saldo que informa \(bank.aspspName ?? "el banco")\(bank.balanceAt.flatMap(CarliDate.instant).map { " (\(CarliDate.dateTime($0)))" } ?? "").")
                    }
                }
                if let actual {
                    Section {
                        let difference = actual - cleared
                        if difference == 0 {
                            Text("El saldo cuadra. No hace falta ningún ajuste.").foregroundStyle(CarliColor.text2)
                        } else {
                            Text("Se creará un movimiento de ajuste de \(Money.format(difference, .signed)).")
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle("Conciliar cuenta")
            .navigationSubtitle(account.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Conciliar", role: .confirm) { save() }.disabled(actual == nil)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            let start = account.bank?.balanceCents ?? cleared
            negative = start < 0
            actualText = Money.input(abs(start))
        }
    }

    private struct Payload: Encodable {
        var actualBalanceCents: Int
        var date: String
    }

    private struct Result: Decodable {
        struct Data: Decodable { var differenceCents: Int; var adjustment: FinanceTransaction? }
        var data: Data
    }

    private func save() {
        guard let actual else { return }
        saving = true
        error = nil
        Task {
            do {
                let result: Result = try await api.post("v1/finance/accounts/\(account.id)/reconcile",
                                                        body: Payload(actualBalanceCents: actual, date: CarliDate.isoDay(date)))
                NotificationCenter.default.post(name: .financeChanged, object: nil)
                onDone(result.data.adjustment != nil
                       ? "Cuenta conciliada · ajuste de \(Money.format(result.data.differenceCents, .signed))"
                       : "Cuenta conciliada · el saldo ya cuadraba")
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "No se ha podido conciliar la cuenta.")
            }
            saving = false
        }
    }
}
