import Foundation

/// Notion 查询 API 返回的 page 对象的通用结构。properties 是 name → 值的字典，
/// 每个值被解析为 `NotionPropertyValue` 枚举，方便 Mapper 按字段名取值。
struct NotionPage: Decodable, Sendable {
    let id: String
    let lastEditedTime: Date
    let archived: Bool
    let properties: [String: NotionPropertyValue]

    enum CodingKeys: String, CodingKey {
        case id
        case lastEditedTime = "last_edited_time"
        case archived
        case properties
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        let editedString = try c.decode(String.self, forKey: .lastEditedTime)
        lastEditedTime = NotionDateParser.parse(editedString) ?? Date()
        archived = (try? c.decode(Bool.self, forKey: .archived)) ?? false
        properties = try c.decode([String: NotionPropertyValue].self, forKey: .properties)
    }
}

struct NotionQueryResponse: Decodable, Sendable {
    let results: [NotionPage]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

enum NotionPropertyValue: Sendable {
    case title(String)
    case richText(String)
    case select(SelectValue?)
    case status(SelectValue?)
    case multiSelect([SelectValue])
    case date(DateRange?)
    case relation([String])
    case number(Double?)
    case checkbox(Bool)
    case url(String?)
    case people([String])
    case unsupported(type: String)

    struct SelectValue: Sendable, Equatable {
        let id: String?
        let name: String
        let color: String?
    }

    struct DateRange: Sendable, Equatable {
        let start: Date?
        let end: Date?
        let timeZone: String?
    }
}

// MARK: - Decoding

extension NotionPropertyValue: Decodable {
    private enum TypeKey: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let type = try typeContainer.decode(String.self, forKey: .type)

        let container = try decoder.container(keyedBy: DynamicKey.self)
        let key = DynamicKey(type)

        switch type {
        case "title":
            let frags = try container.decodeIfPresent([RichTextFragment].self, forKey: key) ?? []
            self = .title(frags.map(\.plainText).joined())
        case "rich_text":
            let frags = try container.decodeIfPresent([RichTextFragment].self, forKey: key) ?? []
            self = .richText(frags.map(\.plainText).joined())
        case "select":
            self = .select(try container.decodeIfPresent(SelectValue.self, forKey: key))
        case "status":
            self = .status(try container.decodeIfPresent(SelectValue.self, forKey: key))
        case "multi_select":
            let arr = try container.decodeIfPresent([SelectValue].self, forKey: key) ?? []
            self = .multiSelect(arr)
        case "date":
            self = .date(try container.decodeIfPresent(DateRange.self, forKey: key))
        case "relation":
            let refs = try container.decodeIfPresent([RelationRef].self, forKey: key) ?? []
            self = .relation(refs.map(\.id))
        case "number":
            self = .number(try container.decodeIfPresent(Double.self, forKey: key))
        case "checkbox":
            self = .checkbox(try container.decodeIfPresent(Bool.self, forKey: key) ?? false)
        case "url":
            self = .url(try container.decodeIfPresent(String.self, forKey: key))
        case "people":
            let arr = try container.decodeIfPresent([PersonRef].self, forKey: key) ?? []
            self = .people(arr.map(\.id))
        default:
            self = .unsupported(type: type)
        }
    }

    private struct RichTextFragment: Decodable {
        let plainText: String
        enum CodingKeys: String, CodingKey { case plainText = "plain_text" }
    }

    private struct RelationRef: Decodable {
        let id: String
    }

    private struct PersonRef: Decodable {
        let id: String
    }
}

extension NotionPropertyValue.SelectValue: Decodable {
    enum CodingKeys: String, CodingKey { case id, name, color }
}

extension NotionPropertyValue.DateRange: Decodable {
    enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = NotionDateParser.parse(try c.decodeIfPresent(String.self, forKey: .start))
        end = NotionDateParser.parse(try c.decodeIfPresent(String.self, forKey: .end))
        timeZone = try c.decodeIfPresent(String.self, forKey: .timeZone)
    }
}

// MARK: - Convenience accessors

extension NotionPage {
    /// 返回第一个 type 为 title 的属性值。Notion 每个数据库有且仅有一个 title，
    /// 但名字会因数据库而异（"标题" / "Name" / "Task name" / "记录" 等），按类型查最稳妥。
    var titleValue: String {
        for (_, value) in properties {
            if case .title(let text) = value {
                return text
            }
        }
        return ""
    }

    func title(named name: String) -> String? {
        guard case .title(let value) = properties[name] else { return nil }
        return value
    }

    func select(named name: String) -> NotionPropertyValue.SelectValue? {
        switch properties[name] {
        case .select(let v?), .status(let v?):
            return v
        default:
            return nil
        }
    }

    func dateRange(named name: String) -> NotionPropertyValue.DateRange? {
        guard case .date(let v) = properties[name] else { return nil }
        return v
    }

    func relationIds(named name: String) -> [String] {
        guard case .relation(let ids) = properties[name] else { return [] }
        return ids
    }
}

// MARK: - Helpers

struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(intValue: Int) { return nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init(_ stringValue: String) { self.stringValue = stringValue }
}

enum NotionDateParser {
    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ value: String?) -> Date? {
        guard let s = value, !s.isEmpty else { return nil }
        if let d = isoFractional.date(from: s) { return d }
        if let d = iso.date(from: s) { return d }
        if let d = dateOnly.date(from: s) { return d }
        return nil
    }
}
