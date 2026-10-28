import Foundation

/// What `GET v1/finance/widget` returns: the period at a glance, today and the latest expenses.
struct WidgetSnapshot: Codable, Equatable {
    struct Period: Codable, Equatable {
        var startDate: String
        var endDate: String
        var remainingDays: Int
        var spentCents: Int
        var budgetedCents: Int
        var budgetRemainingCents: Int
        var budgetPercentBp: Int?
    }

    struct Today: Codable, Equatable {
        var spentCents: Int
        var count: Int
    }

    struct Expense: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var amountCents: Int
        var date: String
    }

    var period: Period
    var today: Today
    var latest: [Expense]

    var hasBudget: Bool { period.budgetedCents > 0 }

    /// Share of the budget already spent, 0...1; nil without budgets.
    var budgetFraction: Double? {
        guard hasBudget, let bp = period.budgetPercentBp else { return nil }
        return min(max(Double(bp) / 10_000, 0), 1)
    }

    static let sample = WidgetSnapshot(
        period: Period(startDate: "2026-10-01", endDate: "2026-11-06", remainingDays: 9, spentCents: 81_200,
                       budgetedCents: 140_000, budgetRemainingCents: 58_800, budgetPercentBp: 5_800),
        today: Today(spentCents: 5_455, count: 2),
        latest: [
            Expense(id: "1", name: "Mercadona", amountCents: -4_215, date: "2026-10-28"),
            Expense(id: "2", name: "Cabify", amountCents: -1_240, date: "2026-10-28"),
        ]
    )
}

/// The few API calls the widget extension makes on its own, with the token the app shares through the Keychain.
enum WidgetAPI {
    static let baseURL = URL(string: "https://carli.jotade.io/api")!

    enum Failure: Error { case signedOut, unavailable }

    nonisolated static func snapshot() async throws(Failure) -> WidgetSnapshot {
        struct Envelope: Decodable { var data: WidgetSnapshot }
        let data = try await send(request(path: "v1/finance/widget", method: "GET"))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else { throw .unavailable }
        return envelope.data
    }

    /// Registers the WidgetKit push token so the server can ask the widgets to reload.
    nonisolated static func registerPushToken(_ token: String) async {
        guard var request = try? request(path: "v1/push-devices", method: "POST") else { return }
        let body = ["token": token, "environment": PushEnvironment.current(), "kind": "widgets"]
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        _ = try? await send(request)
    }

    nonisolated private static func request(path: String, method: String) throws(Failure) -> URLRequest {
        guard let token = TokenStore().read() else { throw .signedOut }
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 15)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    nonisolated private static func send(_ request: URLRequest) async throws(Failure) -> Data {
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { throw .unavailable }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: return data
        case 401: throw .signedOut
        default: throw .unavailable
        }
    }
}
