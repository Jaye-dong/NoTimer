import Foundation
import GRDB

struct NextActionRepository: Sendable {
    let database: AppDatabase

    func upsert(_ action: NextAction) throws {
        try database.writer.write { db in
            var mutable = action
            try mutable.save(db)
        }
    }

    func all() throws -> [NextAction] {
        try database.writer.read { db in
            try NextAction
                .filter(NextAction.Columns.syncState != SyncState.tombstone.rawValue)
                .order(NextAction.Columns.localUpdatedAt.desc)
                .fetchAll(db)
        }
    }

    func openActions() throws -> [NextAction] {
        try database.writer.read { db in
            try NextAction
                .filter(NextAction.Columns.syncState != SyncState.tombstone.rawValue)
                .filter(NextAction.Columns.status != "Done")
                .order(NextAction.Columns.localUpdatedAt.desc)
                .fetchAll(db)
        }
    }

    func byPageId(_ pageId: String) throws -> NextAction? {
        try database.writer.read { db in
            try NextAction
                .filter(NextAction.Columns.notionPageId == pageId)
                .fetchOne(db)
        }
    }

    func applyPulled(_ action: NextAction, existing: NextAction?) throws {
        try database.writer.write { db in
            if let existing {
                if existing.syncState == .pendingPush || existing.syncState == .conflict {
                    var marked = existing
                    marked.syncState = .conflict
                    marked.localUpdatedAt = Date()
                    try marked.update(db)
                    return
                }
                var updated = action
                updated.id = existing.id
                try updated.update(db)
            } else {
                var inserted = action
                try inserted.insert(db)
            }
        }
    }
}
