import Foundation
import GRDB

struct TimeRecord: Identifiable, Codable, Equatable, FetchableRecord, MutablePersistableRecord {
    var id: String
    var notionPageId: String?
    var title: String
    var startAt: Date
    var endAt: Date?
    var category: String?
    var nextActionPageId: String?
    var notionLastEdited: Date?
    var localUpdatedAt: Date
    var syncState: SyncState

    static let databaseTableName = "time_records"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let notionPageId = Column(CodingKeys.notionPageId)
        static let title = Column(CodingKeys.title)
        static let startAt = Column(CodingKeys.startAt)
        static let endAt = Column(CodingKeys.endAt)
        static let category = Column(CodingKeys.category)
        static let nextActionPageId = Column(CodingKeys.nextActionPageId)
        static let notionLastEdited = Column(CodingKeys.notionLastEdited)
        static let localUpdatedAt = Column(CodingKeys.localUpdatedAt)
        static let syncState = Column(CodingKeys.syncState)
    }

    var duration: TimeInterval? {
        guard let endAt else { return nil }
        return endAt.timeIntervalSince(startAt)
    }

    var isActive: Bool { endAt == nil }
}

extension TimeRecord {
    static func new(
        title: String,
        startAt: Date = Date(),
        nextActionPageId: String? = nil,
        category: String? = nil
    ) -> TimeRecord {
        TimeRecord(
            id: UUID().uuidString,
            notionPageId: nil,
            title: title,
            startAt: startAt,
            endAt: nil,
            category: category,
            nextActionPageId: nextActionPageId,
            notionLastEdited: nil,
            localUpdatedAt: Date(),
            syncState: .pendingPush
        )
    }
}
