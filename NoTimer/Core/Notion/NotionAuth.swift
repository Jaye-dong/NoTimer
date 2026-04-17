import Foundation
import Observation

@Observable
final class NotionAuth {
    private let keychain: KeychainStore
    private let tokenKey = "notion.integration.token"

    private(set) var hasToken: Bool = false
    var timeRecordsDatabaseId: String {
        didSet { UserDefaults.standard.set(timeRecordsDatabaseId, forKey: Self.timeRecordsKey) }
    }
    var nextActionsDatabaseId: String {
        didSet { UserDefaults.standard.set(nextActionsDatabaseId, forKey: Self.nextActionsKey) }
    }

    private static let timeRecordsKey = "notion.database.timeRecords"
    private static let nextActionsKey = "notion.database.nextActions"

    init(keychain: KeychainStore) {
        self.keychain = keychain
        self.timeRecordsDatabaseId = UserDefaults.standard.string(forKey: Self.timeRecordsKey) ?? ""
        self.nextActionsDatabaseId = UserDefaults.standard.string(forKey: Self.nextActionsKey) ?? ""
        self.hasToken = (try? keychain.get(tokenKey))?.isEmpty == false
    }

    func token() throws -> String? {
        try keychain.get(tokenKey)
    }

    func saveToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NotionError.emptyToken
        }
        try keychain.set(trimmed, for: tokenKey)
        hasToken = true
    }

    func clearToken() throws {
        try keychain.delete(tokenKey)
        hasToken = false
    }

    /// 从 Notion 数据库 URL 或纯 ID 中抽取 32 位不带连字符的 database id。
    static func extractDatabaseId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.replacingOccurrences(of: "-", with: "")
        // 32 位十六进制
        let pattern = "[0-9a-fA-F]{32}"
        if let match = hex.range(of: pattern, options: .regularExpression) {
            return String(hex[match]).lowercased()
        }
        return nil
    }
}
