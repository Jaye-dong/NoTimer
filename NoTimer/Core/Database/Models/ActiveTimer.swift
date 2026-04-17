import Foundation
import GRDB

struct ActiveTimer: Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64
    var timeRecordId: String
    var startedAt: Date
    var title: String
    var nextActionPageId: String?

    static let databaseTableName = "active_timer"
    static let singletonId: Int64 = 1

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let timeRecordId = Column(CodingKeys.timeRecordId)
        static let startedAt = Column(CodingKeys.startedAt)
        static let title = Column(CodingKeys.title)
        static let nextActionPageId = Column(CodingKeys.nextActionPageId)
    }

    init(timeRecordId: String, startedAt: Date, title: String, nextActionPageId: String?) {
        self.id = Self.singletonId
        self.timeRecordId = timeRecordId
        self.startedAt = startedAt
        self.title = title
        self.nextActionPageId = nextActionPageId
    }
}
