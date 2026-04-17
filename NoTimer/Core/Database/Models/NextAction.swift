import Foundation
import GRDB

struct NextAction: Identifiable, Codable, Equatable, FetchableRecord, MutablePersistableRecord {
    var id: String
    var notionPageId: String?
    var title: String
    var status: String?
    var projectPageId: String?
    var projectName: String?
    var notionLastEdited: Date?
    var localUpdatedAt: Date
    var syncState: SyncState

    static let databaseTableName = "next_actions"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let notionPageId = Column(CodingKeys.notionPageId)
        static let title = Column(CodingKeys.title)
        static let status = Column(CodingKeys.status)
        static let projectPageId = Column(CodingKeys.projectPageId)
        static let projectName = Column(CodingKeys.projectName)
        static let notionLastEdited = Column(CodingKeys.notionLastEdited)
        static let localUpdatedAt = Column(CodingKeys.localUpdatedAt)
        static let syncState = Column(CodingKeys.syncState)
    }
}
