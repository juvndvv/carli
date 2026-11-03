import SwiftUI

/// Links one or more incomes (usually Bizums from the bank) to a contact's share of an expense they
/// pay back. The linked money stops counting as income, and the share stops counting as spending.
struct ReimbursementSheet: View {
    let api: APIClient
    /// Where the sheet was opened from: an income to mark as a reimbursement, or the expense itself.
    let origin: FinanceTransaction
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expenses: [FinanceTransaction] = []
    @State private var incomes: [FinanceTransaction] = []
    @State private var contacts: [ContactRef] = []
    @State private var expenseId: String?
    @State private var incomeIds: Set<String> = []
    @State private var contactId: String?
    @State private var newContactName = ""
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?

    private var fromIncome: Bool { origin.kind == "income" }
    private var effectiveExpenseId: String? { fromIncome ? expenseId : origin.id }
    private var expense: FinanceTransaction? { fromIncome ? expenses.first { $0.id == expenseId } : origin }
    private var selectedCents: Int {
        incomes.filter { incomeIds.contains($0.id) }.reduce(0) { $0 + Self.available($1) }
    }
    private var canSave: Bool { effectiveExpenseId != nil && contactId != nil && !incomeIds.isEmpty && !saving }

    private struct ContactBody: Encodable { var name: String }

    var body: some View {
        NavigationStack {
            Form {
                if fromIncome { expenseSection }
                contactSection
                incomesSection
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .overlay { if loading { ProgressView() } }
            .navigationTitle("Reembolso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Vincular", role: .confirm) { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .task { await load() }
            .task(id: expenseId) { if fromIncome, expenseId != nil { await loadIncomes() } }
        }
        .presentationDetents([.large])
    }

    // MARK: Sections

    private var expenseSection: some View {
        Section {
            if expenses.isEmpty && !loading {
                Text("No hay gastos de los dos últimos meses.").foregroundStyle(CarliColor.text3)
            }
            ForEach(expenses) { candidate in
                row(candidate, selected: expenseId == candidate.id, amount: candidate.amountCents) {
                    expenseId = candidate.id
                }
            }
        } header: {
            Text("¿Qué gasto te devuelven?")
        }
    }

    private var contactSection: some View {
        Section {
            Picker("Quién te paga", selection: $contactId) {
                if contactId == nil { Text("Elegir").tag(String?.none) }
                ForEach(contacts.filter { $0.archived != true }) { contact in
                    Text(contact.name).tag(Optional(contact.id))
                }
            }
            HStack {
                TextField("Nuevo contacto", text: $newContactName)
                    .textInputAutocapitalization(.words)
                Button("Añadir") { Task { await addContact() } }
                    .disabled(newContactName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } footer: {
            Text("Su parte del gasto deja de contar como gasto tuyo.")
        }
    }

    @ViewBuilder
    private var incomesSection: some View {
        if effectiveExpenseId != nil {
            Section {
                if incomes.isEmpty && !loading {
                    Text("No hay ingresos sin vincular desde una semana antes del gasto.").foregroundStyle(CarliColor.text3)
                }
                ForEach(incomes) { income in
                    row(income, selected: incomeIds.contains(income.id), amount: Self.available(income)) {
                        if incomeIds.contains(income.id) { incomeIds.remove(income.id) } else { incomeIds.insert(income.id) }
                    }
                }
            } header: {
                Text("Ingresos que lo pagan")
            } footer: {
                VStack(alignment: .leading, spacing: CarliSpace.s4) {
                    if selectedCents > 0 { Text("Seleccionado: \(Money.format(selectedCents))") }
                    Text("Lo vinculado no cuenta como ingreso ni como gasto. Si supera el gasto, el resto sigue contando como ingreso.")
                }
            }
        }
    }

    private func row(_ transaction: FinanceTransaction, selected: Bool, amount: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CarliSpace.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.title).foregroundStyle(CarliColor.text).lineLimit(1)
                    Text("\(CarliDate.day(transaction.date).map(CarliDate.short) ?? transaction.date) · \(transaction.account.name)")
                        .font(.footnote).foregroundStyle(CarliColor.text2)
                }
                Spacer()
                Text(Money.format(amount, transaction.kind == "income" ? .signed : .plain))
                    .monospacedDigit()
                    .foregroundStyle(transaction.kind == "income" ? CarliColor.positive : CarliColor.text)
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(CarliColor.brandInk)
                    .opacity(selected ? 1 : 0)
            }
        }
    }

    // MARK: Data

    static func available(_ income: FinanceTransaction) -> Int {
        max(0, income.amountCents - (income.reimbursedCents ?? 0))
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let envelope: DataEnvelope<[ContactRef]> = try? await api.get("v1/finance/contacts") {
            contacts = envelope.data
            if contactId == nil, fromIncome, let payee = origin.payee?.lowercased(), !payee.isEmpty {
                contactId = contacts.first { payee.contains($0.name.lowercased()) }?.id
            }
        }
        if fromIncome {
            incomeIds = [origin.id]
            if let envelope: DataEnvelope<[FinanceTransaction]> = try? await api.get(
                "v1/finance/reimbursements/candidates", query: ["income_id": origin.id]) {
                expenses = envelope.data
            }
        } else {
            await loadIncomes()
        }
    }

    private func loadIncomes() async {
        guard let id = effectiveExpenseId else { return }
        let envelope: DataEnvelope<[FinanceTransaction]>? = try? await api.get(
            "v1/finance/reimbursements/candidates", query: ["expense_id": id])
        var list = envelope?.data ?? []
        if fromIncome, !list.contains(where: { $0.id == origin.id }) { list.insert(origin, at: 0) }
        incomes = list
        incomeIds = incomeIds.filter { id in list.contains { $0.id == id } }
    }

    private func addContact() async {
        let name = newContactName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let created: DataEnvelope<ContactRef> = try await api.post("v1/finance/contacts", body: ContactBody(name: name))
            contacts.append(created.data)
            contactId = created.data.id
            newContactName = ""
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido crear el contacto.")
        }
    }

    private func save() async {
        guard let expenseId = effectiveExpenseId, let contactId else { return }
        saving = true
        error = nil
        defer { saving = false }
        do {
            let _: Empty = try await api.post("v1/finance/reimbursements", body: Patch([
                "expense_id": .string(expenseId),
                "contact_id": .string(contactId),
                "income_ids": .array(incomeIds.sorted().map(JSONValue.string)),
            ]))
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            let name = contacts.first { $0.id == contactId }?.name ?? "tu contacto"
            let title = expense?.title ?? "el gasto"
            onDone("\(Money.format(selectedCents)) de \(name) vinculados a \(title)")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido vincular el reembolso.")
        }
    }
}
