import Foundation

/// Thin JSON client for the carli Laravel API (Sanctum bearer tokens).
final class APIClient {
    static let defaultBaseURL = URL(string: "https://carli.jotade.io/api")!

    let baseURL: URL
    private let tokens: TokenStore
    private let session: URLSession
    /// Called when a request that carried a token comes back 401.
    var onUnauthorized: (() -> Void)?

    init(baseURL: URL = APIClient.defaultBaseURL, tokens: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await request("GET", path, query: query, body: Optional<Empty>.none)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try await request("POST", path, body: body)
    }

    func delete(_ path: String) async throws {
        let _: Empty = try await request("DELETE", path, body: Optional<Empty>.none)
    }

    func request<T: Decodable, B: Encodable>(
        _ method: String, _ path: String, query: [String: String] = [:], body: B?
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let token = tokens.read()
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401, token != nil { onUnauthorized?() }
            throw APIError.from(status: status, body: data)
        }
        if data.isEmpty || status == 204, let empty = Empty() as? T {
            return empty
        }
        return try Self.decoder.decode(T.self, from: data)
    }
}

/// Placeholder for requests and responses without a body.
struct Empty: Codable {}
