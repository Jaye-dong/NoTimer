import Foundation
import GRDB

struct TimeRecordRepository: Sendable {
    let database: AppDatabase

    func insert(_ record: TimeRecord) throws {
        try database.writer.write { db in
            var mutable = record
            try mutable.insert(db)
        }
    }

    func update(_ record: TimeRecord) throws {
        try database.writer.write { db in
            var mutable = record
            mutable.localUpdatedAt = Date()
            if mutable.syncState == .synced {
                mutable.syncState = .pendingPush
            }
            try mutable.update(db)
        }
    }

    func recent(limit: Int = 100) throws -> [TimeRecord] {
        try database.writer.read { db in
            try TimeRecord
                .filter(TimeRecord.Columns.syncState != SyncState.tombstone.rawValue)
                .order(TimeRecord.Columns.startAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func activeTimer() throws -> ActiveTimer? {
        try database.writer.read { db in
            try ActiveTimer.fetchOne(db, key: ActiveTimer.singletonId)
        }
    }

    func pendingPush() throws -> [TimeRecord] {
        try database.writer.read { db in
            try TimeRecord
                .filter(TimeRecord.Columns.syncState == SyncState.pendingPush.rawValue)
                .fetchAll(db)
        }
    }

    func conflictCount() throws -> Int {
        try database.writer.read { db in
            try TimeRecord
                .filter(TimeRecord.Columns.syncState == SyncState.conflict.rawValue)
                .fetchCount(db)
        }
    }

    /// Push 成功：写回 Notion 返回的 pageId / lastEdited，置回 synced。
    /// 故意绕开 `update(_:)` — 那个会自动把 synced 翻回 pendingPush。
    func applyPushed(_ recordId: String, notionPageId: String, notionLastEdited: Date) throws {
        try database.writer.write { db in
            guard var record = try TimeRecord.fetchOne(db, key: recordId) else { return }
            record.notionPageId = notionPageId
            record.notionLastEdited = notionLastEdited
            record.syncState = .synced
            try record.update(db)
        }
    }

    func byPageId(_ pageId: String) throws -> TimeRecord? {
        try database.writer.read { db in
            try TimeRecord
                .filter(TimeRecord.Columns.notionPageId == pageId)
                .fetchOne(db)
        }
    }

    /// 从 Notion 拉回的数据覆盖本地；如本地处于 pendingPush / conflict 状态则不覆盖，
    /// 而是升级为 conflict 交由用户解决。
    func applyPulled(_ record: TimeRecord, existing: TimeRecord?) throws {
        try database.writer.write { db in
            if let existing {
                if existing.syncState == .pendingPush || existing.syncState == .conflict {
                    var marked = existing
                    marked.syncState = .conflict
                    marked.localUpdatedAt = Date()
                    try marked.update(db)
                    return
                }
                var updated = record
                updated.id = existing.id
                try updated.update(db)
            } else {
                var inserted = record
                try inserted.insert(db)
            }
        }
    }
}
