import Foundation

enum TimeRecordMapper {
    /// 把 Notion page 转换成本地 TimeRecord。如果同一 notionPageId 已存在，保留本地 id，
    /// 否则生成新 UUID。调用方应当自行处理 sync_state：拉取回来默认置 synced。
    static func toLocal(page: NotionPage, existing: TimeRecord?) -> TimeRecord {
        let title = page.titleValue
        let date = page.dateRange(named: NotionFieldNames.TimeRecord.dateRange)
        let category = page.select(named: NotionFieldNames.TimeRecord.category)?.name
        let nextAction = page.relationIds(named: NotionFieldNames.TimeRecord.nextActionRelation).first

        return TimeRecord(
            id: existing?.id ?? UUID().uuidString,
            notionPageId: page.id,
            title: title,
            startAt: date?.start ?? existing?.startAt ?? page.lastEditedTime,
            endAt: date?.end,
            category: category,
            nextActionPageId: nextAction,
            notionLastEdited: page.lastEditedTime,
            localUpdatedAt: Date(),
            syncState: .synced
        )
    }

    /// 构造 Notion `POST /v1/pages` / `PATCH /v1/pages/{id}` 的 `properties` 字段。
    /// `titleField` 是该数据库里 type=title 属性的名字（由 PullStrategy 缓存）。
    ///
    /// 清零语义（PATCH 时）：category 为 nil 时写 `{ "select": null }` 让 Notion 清空；
    /// relation 为 nil 时写空数组。创建时这些字段可以省略。
    static func toNotionProperties(
        _ record: TimeRecord,
        titleField: String,
        isUpdate: Bool
    ) -> [String: Any] {
        var properties: [String: Any] = [:]

        properties[titleField] = [
            "title": [[
                "type": "text",
                "text": ["content": record.title]
            ]]
        ]

        var dateValue: [String: Any] = ["start": NotionDateFormatter.string(from: record.startAt)]
        if let end = record.endAt {
            dateValue["end"] = NotionDateFormatter.string(from: end)
        }
        properties[NotionFieldNames.TimeRecord.dateRange] = ["date": dateValue]

        if let category = record.category, !category.isEmpty {
            properties[NotionFieldNames.TimeRecord.category] = [
                "select": ["name": category]
            ]
        } else if isUpdate {
            properties[NotionFieldNames.TimeRecord.category] = ["select": NSNull()]
        }

        if let pageId = record.nextActionPageId, !pageId.isEmpty {
            properties[NotionFieldNames.TimeRecord.nextActionRelation] = [
                "relation": [["id": pageId]]
            ]
        } else if isUpdate {
            properties[NotionFieldNames.TimeRecord.nextActionRelation] = ["relation": []]
        }

        return properties
    }
}

enum NotionDateFormatter {
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
