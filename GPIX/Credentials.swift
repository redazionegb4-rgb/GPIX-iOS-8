import Foundation
#if canImport(Security)
import Security
@MainActor enum Credentials {
    private static let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"app.gpix.gpix.native", kSecAttrAccount as String:"token"]
    static func load() -> String {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ token: String) {
        SecItemDelete(query as CFDictionary)
        guard !token.isEmpty else { return }
        var q = query; q[kSecValueData as String] = Data(token.utf8); q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

#else
@MainActor enum Credentials {
    private static var value = ""
    static func load() -> String { value }
    static func save(_ token: String) { value = token }
}
#endif
