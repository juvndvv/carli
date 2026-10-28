import Foundation
import Security

/// The Sanctum token, kept in the Keychain (this device only, after first unlock).
/// It lives in a keychain group shared with the widgets, so they can call the API too.
final class TokenStore {
    /// `$(AppIdentifierPrefix)dev.jotade.personal.shared` in both entitlements files.
    static let sharedGroup = "S5FFHKW385.dev.jotade.personal.shared"

    private let service = "dev.jotade.personal.auth"
    private let account = "auth_token"
    private var cached: String??

    func read() -> String? {
        if let cached { return cached }
        var token = find(group: Self.sharedGroup)
        // Tokens saved before the widgets existed sit in the app's own group: move them over once.
        if token == nil, let legacy = find(group: nil) {
            write(legacy)
            token = legacy
        }
        cached = .some(token)
        return token
    }

    func write(_ token: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrAccessGroup as String] = Self.sharedGroup
        SecItemAdd(query as CFDictionary, nil)
        cached = .some(token)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
        cached = .some(nil)
    }

    private func find(group: String?) -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if let group { query[kSecAttrAccessGroup as String] = group }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
