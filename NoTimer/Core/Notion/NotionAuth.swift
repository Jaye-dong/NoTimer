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
    /// Notion 每个数据库的 title 属性叫什么由用户自己命名（"记录" / "Task name" / "标题"…），
    /// push 时写 properties 必须精确用这个名字。首次 pull 时会把 schema 里 type=title
    /// 的那个属性名缓存在这里。
    var timeRecordsTitleField: String {
        didSet { UserDefaults.standard.set(timeRecordsTitleField, forKey: Self.timeRecordsTitleKey) }
    }
    var nextActionsTitleField: String {
        didSet { UserDefaults.standard.set(nextActionsTitleField, forKey: Self.nextActionsTitleKey) }
    }

    private static let timeRecordsKey = "notion.database.timeRecords"
    private static let nextActionsKey = "notion.database.nextActions"
    private static let timeRecordsTitleKey = "notion.database.timeRecords.titleField"
    private static let nextActionsTitleKey = "notion.database.nextActions.titleField"

    init(keychain: KeychainStore) {
        self.keychain = keychain
        self.timeRecordsDatabaseId = UserDefaults.standard.string(forKey: Self.timeRecordsKey) ?? ""
        self.nextActionsDatabaseId = UserDefaults.standard.string(forKey: Self.nextActionsKey) ?? ""
        self.timeRecordsTitleField = UserDefaults.standard.string(forKey: Self.timeRecordsTitleKey) ?? ""
        self.nextActionsTitleField = UserDefaults.standard.string(forKey: Self.nextActionsTitleKey) ?? ""
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
