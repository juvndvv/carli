import Foundation
import Security

/// The Sanctum token, kept in the Keychain (this device only, after first unlock).
final class TokenStore {
    private let service = "dev.jotade.personal.auth"
    private let account = "auth_token"
    private var cached: String??

    func read() -> String? {
        if let cached { return cached }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let token: String? = SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
            ? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
            : nil
        cached = .some(token)
        return token
    }

    func write(_ token: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
        cached = .some(token)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
        cached = .some(nil)
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
