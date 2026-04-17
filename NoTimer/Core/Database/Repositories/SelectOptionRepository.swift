import Foundation
import GRDB

struct SelectOptionRepository: Sendable {
    let database: AppDatabase

    func replace(kind: SelectOption.DatabaseKind, property: String, options: [SelectOption]) throws {
        try database.writer.write { db in
            try SelectOption
                .filter(SelectOption.Columns.databaseKind == kind.rawValue)
                .filter(SelectOption.Columns.property == property)
                .deleteAll(db)

            for option in options {
                try option.insert(db)
            }
        }
    }

    func options(kind: SelectOption.DatabaseKind, property: String) throws -> [SelectOption] {
        try database.writer.read { db in
            try SelectOption
                .filter(SelectOption.Columns.databaseKind == kind.rawValue)
                .filter(SelectOption.Columns.property == property)
                .order(SelectOption.Columns.name)
                .fetchAll(db)
        }
    }
}
