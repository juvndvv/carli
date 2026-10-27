import Foundation

/// A failed API call, carrying the server's validation message when there is one.
struct APIError: Error, Equatable {
    var status: Int?
    var serverMessage: String?

    static let offline = APIError(status: nil, serverMessage: nil)

    /// The text to show the person, mirroring the Flutter `apiErrorMessage`.
    func message(fallback: String) -> String {
        guard let status else { return "No se puede conectar con el servidor." }
        if status == 429 { return "Demasiados intentos. Espera un minuto y vuelve a probar." }
        if let serverMessage, !serverMessage.isEmpty, status != 500 { return serverMessage }
        return fallback
    }

    /// Laravel error bodies: the first `errors` entry wins over `message`.
    static func from(status: Int, body: Data) -> APIError {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return APIError(status: status)
        }
        if let errors = json["errors"] as? [String: Any],
           let first = errors.values.first as? [Any],
           let text = first.first {
            return APIError(status: status, serverMessage: "\(text)")
        }
        return APIError(status: status, serverMessage: json["message"] as? String)
    }
}

extension Error {
    func apiMessage(fallback: String) -> String {
        (self as? APIError)?.message(fallback: fallback) ?? fallback
    }
}
