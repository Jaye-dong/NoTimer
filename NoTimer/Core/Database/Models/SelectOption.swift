import Foundation
import GRDB

struct SelectOption: Codable, Equatable, FetchableRecord, PersistableRecord {
    var databaseKind: String
    var property: String
    var name: String
    var color: String?

    static let databaseTableName = "select_options"

    enum DatabaseKind: String {
        case timeRecords = "time_records"
        case nextActions = "next_actions"
    }

    enum Columns {
        static let databaseKind = Column(CodingKeys.databaseKind)
        static let property = Column(CodingKeys.property)
        static let name = Column(CodingKeys.name)
        static let color = Column(CodingKeys.color)
    }
}
