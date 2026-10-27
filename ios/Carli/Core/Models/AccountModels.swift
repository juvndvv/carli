import Foundation

/// A full account from /finance/accounts.
struct FinanceAccount: Decodable, Equatable, Identifiable, Hashable {
    struct Bank: Decodable, Equatable, Hashable {
        var connectionId: String?
        var aspspName: String?
        var status: String?
        var lastSyncedAt: String?
        var balanceCents: Int?
        var balanceAt: String?
        var differenceCents: Int?
    }

    var id: String
    var name: String
    var type: String
    var initialBalanceCents: Int?
    var initialBalanceDate: String?
    var balanceCents: Int
    var clearedBalanceCents: Int?
    var pendingCents: Int?
    var creditLimitCents: Int?
    var statementDay: Int?
    var paymentDay: Int?
    var usedCreditCents: Int?
    var availableCreditCents: Int?
    var icon: String?
    var includeInNetWorth: Bool?
    var bank: Bank?
    var archived: Bool?

    var isCreditCard: Bool { type == "credit_card" }
    var isArchived: Bool { archived == true }
    var ref: AccountRef { AccountRef(id: id, name: name) }

    var typeLabel: String { AccountKind(rawValue: type)?.label ?? type }

    var symbol: String {
        if let icon { return CarliIcon.symbol(icon) }
        return AccountKind(rawValue: type)?.symbol ?? "building.columns"
    }

    /// "Tarjeta · fuera del patrimonio"
    var subtitle: String {
        includeInNetWorth == false ? "\(typeLabel) · fuera del patrimonio" : typeLabel
    }

    /// "Corte el día 5 · pago el día 10" for cards with a schedule.
    var cardSchedule: String? {
        guard isCreditCard else { return nil }
        let parts = [statementDay.map { "corte el día \($0)" }, paymentDay.map { "pago el día \($0)" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ").capitalizedFirst
    }
}

struct AccountsPage: Decodable {
    struct Meta: Decodable { var netWorthCents: Int? }
    var data: [FinanceAccount]
    var meta: Meta?
}

enum AccountKind: String, CaseIterable, Identifiable {
    case checking, savings, creditCard = "credit_card", cash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .checking: "Cuenta corriente"
        case .savings: "Ahorro"
        case .creditCard: "Tarjeta de crédito"
        case .cash: "Efectivo"
        }
    }

    var symbol: String {
        switch self {
        case .checking: "building.columns"
        case .savings: "banknote"
        case .creditCard: "creditcard"
        case .cash: "eurosign"
        }
    }
}

nonisolated struct FinanceSettingsFull: Decodable, Equatable {
    var defaultAccountId: String?
    var lastUsedAccountId: String?
    var budgetWarningThreshold: Int?
    var periodMinDays: Int?
    var periodMode: String?
    var remindDaysBefore: Int?
    var savingsTargetPercent: Int?
}

/// A payee the user has used before, with the category it last had.
struct PayeeSuggestion: Decodable, Equatable, Identifiable {
    var payee: String
    var count: Int?
    var lastAmountCents: Int?
    var kind: String?
    var category: CategoryRef?

    var id: String { payee }
}

extension Notification.Name {
    /// Posted after any finance write so open screens reload.
    static let financeChanged = Notification.Name("carli.financeChanged")
}
