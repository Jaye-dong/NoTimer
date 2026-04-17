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
}
