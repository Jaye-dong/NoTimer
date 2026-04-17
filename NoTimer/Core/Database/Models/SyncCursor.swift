import Foundation
import GRDB

struct SyncCursor: Codable, Equatable, FetchableRecord, PersistableRecord {
    var databaseId: String
    var lastEditedAt: Date?
    var lastSyncedAt: Date?

    static let databaseTableName = "sync_cursor"

    enum Columns {
        static let databaseId = Column(CodingKeys.databaseId)
        static let lastEditedAt = Column(CodingKeys.lastEditedAt)
        static let lastSyncedAt = Column(CodingKeys.lastSyncedAt)
    }
}
