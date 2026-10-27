import Foundation

/// After a bank import gets a category, offers to apply it to the similar uncategorized
/// movements and remember the rule (`/similar`, `/categorize-similar`).
enum SimilarCategorization {
    static func offer(api: APIClient, transactionId: String, categoryId: String, categoryName: String,
                      report: @escaping (String) -> Void) async -> UndoOffer? {
        struct Count: Decodable { var count: Int }
        guard let envelope: DataEnvelope<Count> = try? await api.get("v1/finance/transactions/\(transactionId)/similar"),
              envelope.data.count > 0 else { return nil }
        let count = envelope.data.count
        let text = count == 1 ? "Hay 1 movimiento parecido sin categoría" : "Hay \(count) movimientos parecidos sin categoría"
        let action = count == 1 ? "Aplicar al parecido y recordar" : "Aplicar a los \(count) parecidos y recordar"
        return UndoOffer(text: text, action: action, seconds: 10) {
            struct Rule: Decodable { var pattern: String? }
            struct Result: Decodable { var updated: Int; var rule: Rule? }
            do {
                let result: DataEnvelope<Result> = try await api.post(
                    "v1/finance/transactions/\(transactionId)/categorize-similar",
                    body: Patch(["category_id": .string(categoryId), "remember": .bool(true)]))
                let moved = result.data.updated == 1 ? "1 movimiento más" : "\(result.data.updated) movimientos más"
                if let pattern = result.data.rule?.pattern {
                    report("\(moved) en \(categoryName) · regla «\(pattern)» guardada")
                } else {
                    report("\(moved) en \(categoryName)")
                }
                NotificationCenter.default.post(name: .financeChanged, object: nil)
            } catch {
                report(error.apiMessage(fallback: "No se han podido categorizar los parecidos."))
            }
        }
    }
}
