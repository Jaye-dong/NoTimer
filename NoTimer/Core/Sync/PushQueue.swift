import Foundation

/// 把本地 sync_state=pendingPush 的 TimeRecord 推到 Notion。
///
/// 范围与取舍：
/// - 只推「已停止」（endAt 非空）的记录。在计时中的 active timer 不入队，等停止时再推。
/// - 暂不推 NextAction（app 不在本地编辑它们，只读）。
/// - 失败不抛异常：记录错误继续处理剩余条目，Summary 里把失败数给出。
///   调用方决定是否把错误展示给用户。
/// - 没有 notionPageId → POST /v1/pages；有就 PATCH。
actor PushQueue {
    struct Summary: Sendable, Equatable {
        var pushed: Int = 0
        var failed: Int = 0
        var skippedInFlight: Int = 0
        var firstError: String?
    }

    private let client: NotionClient
    private let auth: NotionAuth
    private let timeRecords: TimeRecordRepository

    init(client: NotionClient, auth: NotionAuth, timeRecords: TimeRecordRepository) {
        self.client = client
        self.auth = auth
        self.timeRecords = timeRecords
    }

    func run() async throws -> Summary {
        let dbId = auth.timeRecordsDatabaseId
        let titleField = auth.timeRecordsTitleField
        guard !dbId.isEmpty else { throw NotionError.invalidDatabaseId }
        guard !titleField.isEmpty else {
            // 还没拉过 schema — 先 pull 一次才能知道 title 属性名
            throw NotionError.missingSchema
        }

        var summary = Summary()
        let pending = try timeRecords.pendingPush()

        for record in pending {
            if record.endAt == nil {
                // 正在计时，不推
                summary.skippedInFlight += 1
                continue
            }
            do {
                try await push(record, titleField: titleField, databaseId: dbId)
                summary.pushed += 1
            } catch {
                summary.failed += 1
                if summary.firstError == nil {
                    summary.firstError = error.localizedDescription
                }
            }
        }
        return summary
    }

    private func push(_ record: TimeRecord, titleField: String, databaseId: String) async throws {
        let properties = TimeRecordMapper.toNotionProperties(
            record,
            titleField: titleField,
            isUpdate: record.notionPageId != nil
        )
        let page: NotionPage
        if let pageId = record.notionPageId {
            page = try await client.updatePage(pageId: pageId, properties: properties)
        } else {
            page = try await client.createPage(databaseId: databaseId, properties: properties)
        }
        try timeRecords.applyPushed(
            record.id,
            notionPageId: page.id,
            notionLastEdited: page.lastEditedTime
        )
    }
}
