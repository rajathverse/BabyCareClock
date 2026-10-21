import Foundation
import Security

/// A copy of the saved state and photo in the Keychain. Keychain items outlive the app, so a
/// parent who deletes and reinstalls it can restore everything. It never leaves the iPhone
/// (not synced), but moves to a new iPhone with an encrypted or iCloud backup.
enum KeychainBackup {
    private static let service = "com.rajathverse.childcareclock.backup"
    private static let stateAccount = "state"
    private static let photoAccount = "photo"

    static func saveState(_ state: CareState) {
        guard let json = try? CarePersistence.encode(state),
              let compressed = try? (json as NSData).compressed(using: .lzfse) as Data else { return }
        write(compressed, account: stateAccount)
    }

    static func loadState() -> CareState? {
        guard let compressed = read(account: stateAccount),
              let json = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
              let state = try? CarePersistence.decode(json), state.isSetUp else { return nil }
        return state
    }

    static func savePhoto(_ jpeg: Data?) {
        if let jpeg {
            write(jpeg, account: photoAccount)
        } else {
            remove(account: photoAccount)
        }
    }

    static func loadPhoto() -> Data? { read(account: photoAccount) }

    static func deleteAll() {
        remove(account: stateAccount)
        remove(account: photoAccount)
    }

    // MARK: Keychain

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func write(_ data: Data, account: String) {
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        let status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(query(account).merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    private static func read(account: String) -> Data? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func remove(account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}
