import Foundation
import Observation

/// A contact offered when sharing an expense (`v1/finance/contacts`).
struct ContactRef: Decodable, Identifiable, Equatable {
    var id: String
    var name: String
    var archived: Bool?
}

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

    enum ShareMode: String, CaseIterable, Identifiable {
        case equal, percentage, amount

        var id: String { rawValue }

        var label: String {
            switch self {
            case .equal: "A partes iguales"
            case .percentage: "Porcentaje"
            case .amount: "Importe"
            }
        }
    }

    struct SplitDraft: Identifiable, Equatable {
        let id = UUID()
        var categoryId: String?
        var amountText = ""

        var cents: Int { Money.parse(amountText).map(abs) ?? 0 }
    }

    struct ShareDraft: Identifiable, Equatable {
        var contactId: String
        var name: String
        var percentText = ""
        var amountText = ""

        var id: String { contactId }
        var percentage: Double? { Double(percentText.replacingOccurrences(of: ",", with: ".")) }
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

    var tags: [String] = []
    var tagDraft = ""
    var allTags: [FinanceTag] = []

    var splitEnabled = false
    var splits: [SplitDraft] = []
    var splitsDirty = false

    var shareEnabled = false
    var shareMode = ShareMode.equal
    var includeSelf = true
    var shares: [ShareDraft] = []
    var sharesDirty = false
    var contacts: [ContactRef] = []

    var accounts: [FinanceAccount] = []
    var categories: [FinanceCategory] = []
    var suggestions: [PayeeSuggestion] = []
    var saving = false
    var working = false
    var error: String?

    let api: APIClient

    init(api: APIClient, editing: FinanceTransaction? = nil, kind: Kind = .expense) {
        self.api = api
        self.editing = editing
        self.kind = kind
        if let editing { fill(from: editing, duplicate: false) }
    }

    /// A new movement prefilled from another one, dated today.
    init(api: APIClient, duplicating source: FinanceTransaction) {
        self.api = api
        self.editing = nil
        fill(from: source, duplicate: true)
    }

    private func fill(from source: FinanceTransaction, duplicate: Bool) {
        let outgoing = !source.isTransfer || source.amountCents < 0
        kind = source.kind == "income" ? .income : source.isTransfer ? .transfer : .expense
        amountText = Money.input(abs(source.amountCents))
        payee = source.payee ?? ""
        descriptionText = source.description ?? ""
        notes = source.notes ?? ""
        categoryId = source.category?.id
        accountId = source.isTransfer && !outgoing ? source.transferAccountId : source.account.id
        toAccountId = source.isTransfer ? (outgoing ? source.transferAccountId : source.account.id) : nil
        date = duplicate ? .now : CarliDate.day(source.date) ?? .now
        pending = !duplicate && source.status == "pending"
        tags = source.tags ?? []
        splitEnabled = source.isSplit
        splits = (source.splits ?? []).map { SplitDraft(categoryId: $0.categoryId, amountText: Money.input(abs($0.amountCents ?? 0))) }
        shareEnabled = !(source.shares ?? []).isEmpty
        shareMode = .amount
        shares = (source.shares ?? []).compactMap { share in
            share.contactId.map { ShareDraft(contactId: $0, name: share.name ?? "", amountText: Money.input(abs(share.amountCents ?? 0))) }
        }
        if duplicate {
            splitsDirty = true
            sharesDirty = true
        }
    }

    var isEditing: Bool { editing != nil }
    var isTransferEdit: Bool { editing?.isTransfer == true }

    /// Balance adjustments are shown but not edited here; they can be deleted.
    var isReadOnly: Bool { editing?.kind == "adjustment" }

    var fromBank: Bool { editing?.fromBank == true }
    /// Amount, date and account come from the bank (or from both legs of an undoable transfer).
    var bankLocked: Bool { fromBank || editing?.transferUndoable == true }
    var sharesLocked: Bool { editing?.sharesLocked == true }
    var splitting: Bool { splitEnabled && kind != .transfer }
    var isSplit: Bool { splitting }

    var amount: Int? { Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }

    var activeAccounts: [FinanceAccount] {
        let involved: Set<String?> = [editing?.account.id, editing?.transferAccountId, accountId, toAccountId]
        return accounts.filter { !$0.isArchived || involved.contains($0.id) }
    }

    /// Manual accounts a bank movement can be linked to as a transfer.
    var manualAccounts: [FinanceAccount] {
        accounts.filter { !$0.isArchived && $0.bank == nil && $0.id != editing?.account.id }
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
    var categoryLabel: String? { label(for: categoryId) }

    func label(for id: String?) -> String? {
        guard let id else { return nil }
        for parent in categories {
            if parent.id == id { return parent.name }
            if let child = parent.children?.first(where: { $0.id == id }) { return "\(parent.name) › \(child.name)" }
        }
        return editing?.category?.id == id ? editing?.category?.label : nil
    }

    var splitRemaining: Int { (amount ?? 0) - splits.reduce(0) { $0 + $1.cents } }

    /// What each contact owes for the current mode, as the server will compute it.
    var sharePreview: [(name: String, cents: Int)] {
        let total = amount ?? 0
        guard !shares.isEmpty, total > 0 else { return shares.map { ($0.name, 0) } }
        switch shareMode {
        case .equal:
            let parts = shares.count + (includeSelf ? 1 : 0)
            let base = total / parts
            let remainder = includeSelf ? 0 : total - base * parts
            return shares.enumerated().map { ($1.name, base + ($0 < remainder ? 1 : 0)) }
        case .percentage:
            return shares.map { ($0.name, Int((Double(total) * ((($0.percentage ?? 0) * 100).rounded()) / 10_000).rounded())) }
        case .amount:
            return shares.map { ($0.name, Money.parse($0.amountText).map(abs) ?? 0) }
        }
    }

    var shareSummary: String? {
        let preview = sharePreview
        guard !preview.isEmpty else { return nil }
        let total = amount ?? 0
        let shared = preview.reduce(0) { $0 + $1.cents }
        if shared > total { return "La parte compartida supera el importe del gasto." }
        let own = total - shared
        if preview.count == 1 { return "\(preview[0].name) te debe \(Money.format(preview[0].cents)) · tu parte \(Money.format(own))" }
        return "Te deben \(Money.format(shared)) · tu parte \(Money.format(own))"
    }

    var canSave: Bool {
        guard !saving, !isReadOnly, amount != nil, accountId != nil else { return false }
        switch kind {
        case .transfer: return isTransferEdit || (toAccountId != nil && toAccountId != accountId)
        case .expense, .income: return categoryId != nil || splitting
        }
    }

    func load() async {
        async let accounts: Void = loadAccounts()
        async let categories: Void = loadCategories()
        _ = await (accounts, categories)
        if let envelope: DataEnvelope<[FinanceTag]> = try? await api.get("v1/finance/tags") { allTags = envelope.data }
        if let envelope: DataEnvelope<[ContactRef]> = try? await api.get("v1/finance/contacts") {
            contacts = envelope.data.filter { $0.archived != true }
        }
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

    // MARK: Tags, splits, shares

    static func parseTags(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { $0.replacing(/^#+/, with: "").lowercased() }
            .filter { !$0.isEmpty }
    }

    func commitTagDraft() {
        let additions = Self.parseTags(tagDraft)
        tagDraft = ""
        for tag in additions where !tags.contains(tag) { tags.append(tag) }
    }

    func setSplitEnabled(_ on: Bool) {
        splitEnabled = on
        splitsDirty = true
        if on && splits.isEmpty {
            splits = [SplitDraft(categoryId: categoryId, amountText: amountText), SplitDraft()]
        }
    }

    func removeSplit(_ split: SplitDraft) {
        splits.removeAll { $0.id == split.id }
        splitsDirty = true
        if splits.isEmpty { splitEnabled = false }
    }

    func toggleShare(_ contact: ContactRef) {
        sharesDirty = true
        if let index = shares.firstIndex(where: { $0.contactId == contact.id }) {
            shares.remove(at: index)
        } else {
            shares.append(ShareDraft(contactId: contact.id, name: contact.name, percentText: shares.isEmpty ? "50" : ""))
        }
    }

    // MARK: Saving

    /// A bank import that just got its first category: Movimientos offers to apply it to similar ones.
    var categorizedImport: (transactionId: String, categoryId: String, name: String)? {
        guard let editing, editing.category == nil, !editing.isSplit, !splitting, kind != .transfer,
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

    private func text(_ value: String) -> JSONValue {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .null : .string(trimmed)
    }

    func save() async -> Bool {
        guard canSave, let amount, let accountId else { return false }
        commitTagDraft()
        if splitting && splitRemaining != 0 {
            error = "El reparto entre categorías debe sumar el importe total."
            return false
        }
        let sharing = kind == .expense && shareEnabled && !shares.isEmpty
        if sharing && sharePreview.reduce(0, { $0 + $1.cents }) > amount {
            error = "La parte compartida supera el importe del gasto."
            return false
        }
        saving = true
        error = nil
        defer { saving = false }
        let status: JSONValue = .string(pending ? "pending" : "cleared")
        let tagList: JSONValue = .array(tags.map(JSONValue.string))
        do {
            if kind == .transfer {
                var body: [String: JSONValue] = ["amount_cents": .int(amount), "date": .string(CarliDate.isoDay(date)),
                                                 "description": text(descriptionText), "notes": text(notes),
                                                 "status": status, "tags": tagList]
                if let editing {
                    let _: Empty = try await api.patch("v1/finance/transactions/\(editing.id)", body: Patch(body))
                } else {
                    body["from_account_id"] = .string(accountId)
                    body["to_account_id"] = .optional(toAccountId)
                    let _: Empty = try await api.post("v1/finance/transfers", body: Patch(body))
                }
            } else {
                var body: [String: JSONValue] = [
                    "account_id": .string(accountId), "kind": .string(kind.rawValue),
                    "amount_cents": .int(kind == .expense ? -amount : amount), "date": .string(CarliDate.isoDay(date)),
                    "category_id": splitting ? .null : .optional(categoryId), "payee": text(payee),
                    "description": text(descriptionText), "notes": text(notes), "status": status, "tags": tagList,
                ]
                if editing == nil || splitsDirty {
                    if splitting {
                        body["splits"] = .array(splits.compactMap { split in
                            guard let category = split.categoryId, split.cents != 0 else { return nil }
                            return .object(["category_id": .string(category),
                                            "amount_cents": .int(kind == .expense ? -split.cents : split.cents)])
                        })
                    } else if editing?.isSplit == true {
                        body["splits"] = .null
                    }
                }
                if !sharesLocked && (editing == nil || sharesDirty) {
                    if sharing {
                        var input: [String: JSONValue] = ["mode": .string(shareMode.rawValue)]
                        if shareMode == .equal { input["include_self"] = .bool(includeSelf) }
                        input["items"] = .array(shares.map { share in
                            var item: [String: JSONValue] = ["contact_id": .string(share.contactId)]
                            if shareMode == .percentage { item["percentage"] = share.percentage.map(JSONValue.double) ?? .null }
                            if shareMode == .amount { item["amount_cents"] = .optional(Money.parse(share.amountText).map(abs)) }
                            return .object(item)
                        })
                        body["shares"] = .object(input)
                    } else if !(editing?.shares ?? []).isEmpty {
                        body["shares"] = .null
                    }
                }
                if let editing {
                    let _: Empty = try await api.patch("v1/finance/transactions/\(editing.id)", body: Patch(body))
                } else {
                    let _: Empty = try await api.post("v1/finance/transactions", body: Patch(body))
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

    /// Splits an auto-detected or confirmed transfer back into an expense and an income.
    func undoTransfer() async -> String? {
        guard let editing else { return nil }
        working = true
        defer { working = false }
        do {
            let _: Empty = try await api.post("v1/finance/transactions/\(editing.id)/undo-transfer", body: Patch([:]))
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            return editing.transferSource == "linked" ? "Transferencia deshecha" : "Transferencia deshecha · no se volverá a sugerir"
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido deshacer la transferencia.")
            return nil
        }
    }

    /// Links a bank movement with a manual account as a transfer.
    func convertToTransfer(_ account: FinanceAccount) async -> String? {
        guard let editing else { return nil }
        working = true
        defer { working = false }
        do {
            let _: Empty = try await api.post("v1/finance/transactions/\(editing.id)/convert-to-transfer",
                                               body: Patch(["account_id": .string(account.id)]))
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            return editing.amountCents < 0 ? "Transferencia a \(account.name)" : "Transferencia desde \(account.name)"
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido convertir en transferencia.")
            return nil
        }
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
