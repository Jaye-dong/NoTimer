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

    /// 取与 [start, end) 有交集、已结束的记录。供统计页按日期段查询，避免把全量记录读进内存。
    /// 交集条件：endAt >= start AND startAt < end。
    func completed(overlapping start: Date, and end: Date) throws -> [TimeRecord] {
        try database.writer.read { db in
            try TimeRecord
                .filter(TimeRecord.Columns.syncState != SyncState.tombstone.rawValue)
                .filter(TimeRecord.Columns.endAt != nil)
                .filter(TimeRecord.Columns.endAt >= start)
                .filter(TimeRecord.Columns.startAt < end)
                .order(TimeRecord.Columns.startAt.asc)
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

    func tombstoned() throws -> [TimeRecord] {
        try database.writer.read { db in
            try TimeRecord
                .filter(TimeRecord.Columns.syncState == SyncState.tombstone.rawValue)
                .fetchAll(db)
        }
    }

    /// 逻辑删除：有 Notion page 的置 tombstone，等 PushQueue 归档并物理删除；
    /// 本地新建从没同步过的直接物理删除。
    func delete(id: String) throws {
        try database.writer.write { db in
            guard let record = try TimeRecord.fetchOne(db, key: id) else { return }
            if record.notionPageId != nil {
                var marked = record
                marked.syncState = .tombstone
                marked.localUpdatedAt = Date()
                try marked.update(db)
            } else {
                _ = try TimeRecord.deleteOne(db, key: id)
            }
        }
    }

    /// Push 成功归档后从本地物理删除。
    func purge(id: String) throws {
        try database.writer.write { db in
            _ = try TimeRecord.deleteOne(db, key: id)
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
    /// 而是升级为 conflict 交由用户解决。tombstone 状态保留不动 —— 下一次 push 会归档。
    func applyPulled(_ record: TimeRecord, existing: TimeRecord?) throws {
        try database.writer.write { db in
            if let existing {
                if existing.syncState == .tombstone { return }
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
