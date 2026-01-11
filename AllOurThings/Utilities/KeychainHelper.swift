import Foundation
import Security

// MARK: - Secure Keychain Storage

class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = Constants.Keychain.service

    // Future secure storage methods can be added here
}
