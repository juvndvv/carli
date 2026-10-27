import Foundation
import Observation

/// Data for Finanzas › Resumen: the dashboard of the chosen period plus what it needs around it.
@Observable
final class FinanceSummaryModel {
    enum State: Equatable { case loading, loaded(Dashboard), failed(String) }

    var state: State = .loading
    var periods: [FinancePeriod] = []
    var selectedPeriodId: String?
    var accounts: [AccountRef]?
    var savingsTargetPercent = 20

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var selectedPeriod: FinancePeriod? {
        periods.first { $0.id == selectedPeriodId } ?? state.dashboard?.period
    }

    func load() async {
        async let periods: Void = loadPeriods()
        async let accounts: Void = loadAccounts()
        async let settings: Void = loadSettings()
        async let dashboard: Void = loadDashboard()
        _ = await (periods, accounts, settings, dashboard)
    }

    func select(_ period: FinancePeriod) async {
        selectedPeriodId = period.id
        await loadDashboard()
    }

    func loadDashboard() async {
        do {
            let query = selectedPeriodId.map { ["period_id": $0] } ?? [:]
            let envelope: DataEnvelope<Dashboard> = try await api.get("v1/finance/dashboard", query: query)
            state = .loaded(envelope.data)
        } catch {
            if state.dashboard == nil { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
    }

    private func loadPeriods() async {
        if let envelope: DataEnvelope<[FinancePeriod]> = try? await api.get("v1/finance/periods") {
            periods = envelope.data
        }
    }

    private func loadAccounts() async {
        if let envelope: DataEnvelope<[AccountRef]> = try? await api.get("v1/finance/accounts", query: ["include_archived": "1"]) {
            accounts = envelope.data
        }
    }

    private func loadSettings() async {
        if let envelope: DataEnvelope<FinanceSettings> = try? await api.get("v1/finance/settings") {
            savingsTargetPercent = envelope.data.savingsTargetPercent ?? 20
        }
    }
}

extension FinanceSummaryModel.State {
    var dashboard: Dashboard? {
        if case .loaded(let dashboard) = self { dashboard } else { nil }
    }
}
