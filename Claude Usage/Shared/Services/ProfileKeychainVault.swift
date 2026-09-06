import Foundation
import Security

/// Injectable boundary: unit tests use memory rather than real account storage.
protocol ProfileCredentialStorage {
    func loadProfileVault() throws -> Data?
    func saveProfileVault(_ data: Data) throws
}

/// Use the encrypted macOS login Keychain for locally built, unentitled apps.
/// SecAccessControl/data-protection attributes require entitlements that this
/// fork's unsigned builds do not have. The login Keychain enforces its normal
/// per-application ACL; a rebuilt app may need the user's Keychain approval.
final class ProfileKeychainVault: ProfileCredentialStorage {
    static let shared = ProfileKeychainVault()
    private let service: String

    init(service: String = "com.claudeusagetracker.profile-credentials") {
        self.service = service
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "profile-vault",
            kSecUseDataProtectionKeychain as String: false
        ]
    }

    func loadProfileVault() throws -> Data? {
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.loadFailed(status: status) }
        guard let data = result as? Data else { throw KeychainError.invalidData }
        return data
    }

    func saveProfileVault(_ data: Data) throws {
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError.saveFailed(status: status) }
        var add = query
        add[kSecValueData as String] = data
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw KeychainError.saveFailed(status: added) }
    }
}
