import Foundation
import Security

// MARK: - Secure Keychain Storage for API Keys

class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = Constants.Keychain.service
    private let geminiKeyAccount = Constants.Keychain.geminiKeyAccount

    // MARK: - Save API Key

    func saveGeminiKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else {
            return false
        }

        // Delete any existing key first
        deleteGeminiKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: geminiKeyAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Retrieve API Key

    func getGeminiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: geminiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    // MARK: - Delete API Key

    func deleteGeminiKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: geminiKeyAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Check if Key Exists

    func hasGeminiKey() -> Bool {
        return getGeminiKey() != nil
    }
}
