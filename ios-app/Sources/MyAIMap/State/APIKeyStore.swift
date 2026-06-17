import Foundation
import Security

/// The only Keychain touch-point for the Anthropic API key.
/// Keeps the secret out of UserDefaults, exports, and the bundle.
/// Modelled after `HistoryStore` — thin wrapper, injectable service
/// string so tests can isolate with a unique name and clean up.
struct APIKeyStore {
    private let service: String

    init(service: String = "com.myaimap.anthropicAPIKey") {
        self.service = service
    }

    // MARK: - Public interface

    /// Upsert the key. Throws if Keychain returns an unexpected status.
    func save(_ key: String) throws {
        guard let data = key.data(using: .utf8) else { return }

        // Try add first; if duplicate, fall through to update.
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return }

        guard addStatus == errSecDuplicateItem else {
            throw KeychainError(status: addStatus)
        }

        // Duplicate — update instead.
        let findQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        let updateStatus = SecItemUpdate(
            findQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus != errSecSuccess {
            throw KeychainError(status: updateStatus)
        }
    }

    /// Returns the stored key, or nil when absent.
    func read() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    /// Remove the key from the Keychain. No-op when absent.
    func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// True when a key is present in the Keychain.
    var hasKey: Bool { read() != nil }
}

// MARK: - Error

struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Keychain error \(status)" }
}
