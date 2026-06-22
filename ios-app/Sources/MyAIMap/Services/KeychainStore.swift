import Foundation
import Security

/// Minimal Keychain wrapper for secrets that must never touch UserDefaults or
/// the persisted universe (e.g. the user-provided DeepSeek API key). Stores a
/// single string value per account under one service.
///
/// Security: values live in the system Keychain, are never logged, and are
/// never committed. The key is supplied by the user at runtime.
enum KeychainStore {
    /// Keychain service namespace for the app's secrets.
    static let service = "com.ilyatur.myaimap.secrets"
    /// Account used for the user's DeepSeek API key.
    static let deepSeekAPIKeyAccount = "deepseek.apiKey"

    /// Saves (or replaces) the trimmed value. An empty/whitespace value deletes
    /// the entry so "clearing the field" behaves like "remove the key".
    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return delete(account: account)
        }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            let addQuery = query.merging(attributes) { _, new in new }
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Loads the stored value, or nil when nothing is set.
    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func hasValue(account: String) -> Bool {
        load(account: account) != nil
    }
}
