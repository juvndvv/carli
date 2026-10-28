import Foundation

/// Loosely typed JSON for bodies whose keys vary (module settings, partial PATCHes).
enum JSONValue: Encodable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    static func optional(_ value: String?) -> JSONValue { value.map(JSONValue.string) ?? .null }
    static func optional(_ value: Int?) -> JSONValue { value.map(JSONValue.int) ?? .null }
}

extension JSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }
}

/// A partial PATCH body: keys are sent as written (already snake_case), nulls included.
struct Patch: Encodable {
    var fields: [String: JSONValue]

    init(_ fields: [String: JSONValue]) {
        self.fields = fields
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for (key, value) in fields {
            try container.encode(value, forKey: Key(stringValue: key))
        }
    }
}

/// Reads and writes a module's free-form settings (`/v1/modules`).
enum ModuleSettings {
    private struct Entry<S: Decodable>: Decodable {
        var id: String
        var settings: S?
    }

    static func load<S: Decodable>(_ api: APIClient, module: String, as type: S.Type = S.self) async -> S? {
        guard let list: DataEnvelope<[Entry<S>]> = try? await api.get("v1/modules") else { return nil }
        return list.data.first { $0.id == module }?.settings ?? nil
    }

    static func save(_ api: APIClient, module: String, _ fields: [String: JSONValue]) async throws {
        let _: Empty = try await api.patch("v1/modules/\(module)", body: Patch(["settings": .object(fields)]))
    }
}
