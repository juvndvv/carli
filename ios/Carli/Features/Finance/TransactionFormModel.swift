import Foundation
import Observation

/// State behind the new/edit movement sheet.
@Observable
final class TransactionFormModel {
    enum Kind: String, CaseIterable, Identifiable {
        case expense, income, transfer

        var id: String { rawValue }

        var label: String {
            switch self {
            case .expense: "Gasto"
            case .income: "Ingreso"
            case .transfer: "Transferencia"
            }
        }
    }

    let editing: FinanceTransaction?

    var kind: Kind = .expense
    var amountText = ""
    var payee = ""
    var descriptionText = ""
    var notes = ""
    var categoryId: String?
    var accountId: String?
    var toAccountId: String?
    var date = Date.now
    var pending = false

    var accounts: [FinanceAccount] = []
    var categories: [FinanceCategory] = []
    var suggestions: [PayeeSuggestion] = []
    var saving = false
    var error: String?

    private let api: APIClient

    init(api: APIClient, editing: FinanceTransaction? = nil, kind: Kind = .expense) {
        self.api = api
        self.editing = editing
        self.kind = kind
        if let editing {
            self.kind = editing.kind == "income" ? .income : editing.isTransfer ? .transfer : .expense
            amountText = Money.input(abs(editing.amountCents))
            payee = editing.payee ?? ""
            descriptionText = editing.description ?? ""
            notes = editing.notes ?? ""
            categoryId = editing.category?.id
            accountId = editing.account.id
            date = CarliDate.day(editing.date) ?? .now
            pending = editing.status == "pending"
        }
    }

    var isEditing: Bool { editing != nil }

    /// Transfers and balance adjustments are shown but not edited here; they can be deleted.
    var isReadOnly: Bool { editing.map { $0.isTransfer || $0.kind == "adjustment" } ?? false }

    var isSplit: Bool { editing?.isSplit ?? false }

    var amount: Int? { Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }

    var activeAccounts: [FinanceAccount] {
        accounts.filter { !$0.isArchived || $0.id == accountId }
    }

    var categoryKind: String { kind == .income ? "income" : "expense" }

    var selectedCategory: FinanceCategory? {
        guard let categoryId else { return nil }
        for parent in categories {
            if parent.id == categoryId { return parent }
            if let child = parent.children?.first(where: { $0.id == categoryId }) { return child }
        }
        return nil
    }

    /// "Comer fuera › Restaurantes" or the category name from the movement while the list loads.
    var categoryLabel: String? {
        guard let categoryId else { return nil }
        for parent in categories {
            if parent.id == categoryId { return parent.name }
            if let child = parent.children?.first(where: { $0.id == categoryId }) { return "\(parent.name) › \(child.name)" }
        }
        return editing?.category?.id == categoryId ? editing?.category?.label : nil
    }

    var canSave: Bool {
        guard !saving, !isReadOnly, amount != nil, accountId != nil else { return false }
        switch kind {
        case .transfer: return toAccountId != nil && toAccountId != accountId
        case .expense, .income: return categoryId != nil || isSplit
        }
    }

    func load() async {
        async let accounts: Void = loadAccounts()
        async let categories: Void = loadCategories()
        _ = await (accounts, categories)
    }

    func suggest() async {
        let query = payee.trimmingCharacters(in: .whitespaces)
        guard kind != .transfer, query.count >= 2, !isEditing else { suggestions = []; return }
        let envelope: DataEnvelope<[PayeeSuggestion]>? = try? await api.get("v1/finance/payees/suggest",
                                                                          query: ["q": query, "kind": categoryKind, "limit": "5"])
        let found = envelope?.data ?? []
        suggestions = found.filter { $0.payee.caseInsensitiveCompare(query) != .orderedSame || categoryId == nil }
    }

    func apply(_ suggestion: PayeeSuggestion) {
        payee = suggestion.payee
        if let category = suggestion.category?.id { categoryId = category }
        if amountText.isEmpty, let last = suggestion.lastAmountCents, last != 0 { amountText = Money.input(abs(last)) }
        suggestions = []
    }

    /// A bank import that just got its first category: Movimientos offers to apply it to similar ones.
    var categorizedImport: (transactionId: String, categoryId: String, name: String)? {
        guard let editing, editing.category == nil, !isSplit, kind != .transfer,
              editing.kind == kind.rawValue, let categoryId else { return nil }
        return (editing.id, categoryId, categoryName(categoryId))
    }

    private func categoryName(_ id: String) -> String {
        for parent in categories {
            if parent.id == id { return parent.name }
            if let child = parent.children?.first(where: { $0.id == id }) { return child.name }
        }
        return "la categoría elegida"
    }

    func save() async -> Bool {
        guard canSave, let amount, let accountId else { return false }
        saving = true
        error = nil
        defer { saving = false }
        do {
            if kind == .transfer {
                let body = TransferInput(fromAccountId: accountId, toAccountId: toAccountId ?? "", amountCents: amount,
                                         date: CarliDate.isoDay(date), description: trimmed(descriptionText),
                                         notes: trimmed(notes), status: pending ? "pending" : "cleared")
                let _: Empty = try await api.post("v1/finance/transfers", body: body)
            } else {
                let body = TransactionInput(accountId: accountId, kind: kind.rawValue,
                                            amountCents: kind == .expense ? -amount : amount,
                                            date: CarliDate.isoDay(date), categoryId: isSplit ? nil : categoryId,
                                            payee: trimmed(payee), description: trimmed(descriptionText),
                                            notes: trimmed(notes), status: pending ? "pending" : "cleared")
                if let editing {
                    let _: Empty = try await api.patch("v1/finance/transactions/\(editing.id)", body: body)
                } else {
                    let _: Empty = try await api.post("v1/finance/transactions", body: body)
                }
            }
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            return true
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el movimiento.")
            return false
        }
    }

    func delete() async -> Bool {
        guard let editing else { return false }
        do {
            try await api.delete("v1/finance/transactions/\(editing.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            return true
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido eliminar el movimiento.")
            return false
        }
    }

    private func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func loadAccounts() async {
        async let page = fetchAccounts()
        async let settings = fetchSettings()
        let (loaded, prefs) = await (page, settings)
        accounts = loaded?.data ?? []
        if accountId == nil {
            let active = accounts.filter { !$0.isArchived }
            let preferred = [prefs?.data.defaultAccountId, prefs?.data.lastUsedAccountId].compactMap { $0 }
            accountId = preferred.first { id in active.contains { $0.id == id } } ?? active.first?.id
        }
    }

    private func fetchAccounts() async -> AccountsPage? {
        try? await api.get("v1/finance/accounts", query: ["include_archived": "1"])
    }

    private func fetchSettings() async -> DataEnvelope<FinanceSettingsFull>? {
        try? await api.get("v1/finance/settings")
    }

    private func loadCategories() async {
        if let envelope: DataEnvelope<[FinanceCategory]> = try? await api.get("v1/finance/categories") {
            categories = envelope.data
        }
    }
}

/// Create/patch body. Text fields are always sent so clearing one removes it.
struct TransactionInput: Encodable {
    var accountId: String
    var kind: String
    var amountCents: Int
    var date: String
    var categoryId: String?
    var payee: String?
    var description: String?
    var notes: String?
    var status: String

    private enum CodingKeys: String, CodingKey {
        case accountId, kind, amountCents, date, categoryId, payee, description, notes, status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(kind, forKey: .kind)
        try container.encode(amountCents, forKey: .amountCents)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(payee, forKey: .payee)
        try container.encode(description, forKey: .description)
        try container.encode(notes, forKey: .notes)
        try container.encode(status, forKey: .status)
    }
}

struct TransferInput: Encodable {
    var fromAccountId: String
    var toAccountId: String
    var amountCents: Int
    var date: String
    var description: String?
    var notes: String?
    var status: String
}
