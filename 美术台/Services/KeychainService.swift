import Foundation
import Security

enum KeychainService {
    private static let service = "com.assetdesk.deepseek"
    private static let deepSeekAccount = "api-key"
    private static let openAICompatibleAccount = "openai-compatible-api-key"

    static func readAPIKey() -> String {
        readAPIKey(account: deepSeekAccount)
    }

    static func readOpenAICompatibleAPIKey() -> String {
        readAPIKey(account: openAICompatibleAccount)
    }

    static func saveAPIKey(_ value: String) throws {
        try saveAPIKey(value, account: deepSeekAccount)
    }

    static func saveOpenAICompatibleAPIKey(_ value: String) throws {
        try saveAPIKey(value, account: openAICompatibleAccount)
    }

    private static func readAPIKey(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return value
    }

    private static func saveAPIKey(_ value: String, account: String) throws {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(lookup as CFDictionary)

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        var entry = lookup
        entry[kSecValueData as String] = Data(trimmed.utf8)
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(entry as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "无法安全保存 API Key（Keychain 状态码：\(status)）。"
        }
    }
}
