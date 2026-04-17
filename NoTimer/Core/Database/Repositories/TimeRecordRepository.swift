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
}
