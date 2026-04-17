import Foundation

/// 负责从 Notion 全量/增量拉取两个数据库到本地。M2 里只做拉取方向，
/// push 在 M4 里由 SyncEngine 组合。
actor PullStrategy {
    struct Summary: Sendable, Equatable {
        var timeRecordsPulled: Int = 0
        var nextActionsPulled: Int = 0
    }

    private let client: NotionClient
    private let auth: NotionAuth
    private let timeRecords: TimeRecordRepository
    private let nextActions: NextActionRepository
    private let selectOptions: SelectOptionRepository

    init(
        client: NotionClient,
        auth: NotionAuth,
        timeRecords: TimeRecordRepository,
        nextActions: NextActionRepository,
        selectOptions: SelectOptionRepository
    ) {
        self.client = client
        self.auth = auth
        self.timeRecords = timeRecords
        self.nextActions = nextActions
        self.selectOptions = selectOptions
    }

    /// 按 schema 同步 select / status 选项，再拉取两个数据库的所有 page。
    func runFullPull() async throws -> Summary {
        let timeDbId = auth.timeRecordsDatabaseId
        let actionsDbId = auth.nextActionsDatabaseId
        guard !timeDbId.isEmpty, !actionsDbId.isEmpty else {
            throw NotionError.invalidDatabaseId
        }

        try await syncSelectOptions(
            databaseId: timeDbId,
            kind: .timeRecords,
            properties: [NotionFieldNames.TimeRecord.category]
        )
        try await syncSelectOptions(
            databaseId: actionsDbId,
            kind: .nextActions,
            properties: [NotionFieldNames.NextAction.status]
        )

        var summary = Summary()
        summary.timeRecordsPulled = try await pullTimeRecords(databaseId: timeDbId)
        summary.nextActionsPulled = try await pullNextActions(databaseId: actionsDbId)
        return summary
    }

    // MARK: - Per-database

    private func pullTimeRecords(databaseId: String) async throws -> Int {
        let pages = try await client.queryDatabase(id: databaseId)
        for page in pages {
            let existing = try timeRecords.byPageId(page.id)
            let record = TimeRecordMapper.toLocal(page: page, existing: existing)
            try timeRecords.applyPulled(record, existing: existing)
        }
        return pages.count
    }

    private func pullNextActions(databaseId: String) async throws -> Int {
        let pages = try await client.queryDatabase(id: databaseId)
        for page in pages {
            let existing = try nextActions.byPageId(page.id)
            let action = NextActionMapper.toLocal(page: page, existing: existing)
            try nextActions.applyPulled(action, existing: existing)
        }
        return pages.count
    }

    // MARK: - Select / Status options

    private func syncSelectOptions(
        databaseId: String,
        kind: SelectOption.DatabaseKind,
        properties: [String]
    ) async throws {
        let info = try await client.fetchDatabase(id: databaseId)
        for property in properties {
            guard let schema = info.properties[property] else { continue }
            let options: [SelectOption]
            if let sel = schema.select {
                options = sel.options.map {
                    SelectOption(databaseKind: kind.rawValue, property: property, name: $0.name, color: $0.color)
                }
            } else if let status = schema.status {
                options = status.options.map {
                    SelectOption(databaseKind: kind.rawValue, property: property, name: $0.name, color: $0.color)
                }
            } else if let multi = schema.multiSelect {
                options = multi.options.map {
                    SelectOption(databaseKind: kind.rawValue, property: property, name: $0.name, color: $0.color)
                }
            } else {
                continue
            }
            try selectOptions.replace(kind: kind, property: property, options: options)
        }
    }
}
