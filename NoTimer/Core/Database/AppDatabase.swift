import Foundation
import GRDB

final class AppDatabase: Sendable {
    let writer: DatabaseWriter

    init(_ writer: DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    static func onDisk() throws -> AppDatabase {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("NoTimer", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("app.sqlite")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let pool = try DatabasePool(path: url.path, configuration: config)
        return try AppDatabase(pool)
    }

    static func inMemory() throws -> AppDatabase {
        try AppDatabase(try DatabaseQueue())
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "time_records") { t in
                t.column("id", .text).primaryKey()
                t.column("notionPageId", .text).unique()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("startAt", .datetime).notNull()
                t.column("endAt", .datetime)
                t.column("category", .text)
                t.column("nextActionPageId", .text).indexed()
                t.column("notionLastEdited", .datetime)
                t.column("localUpdatedAt", .datetime).notNull()
                t.column("syncState", .integer).notNull().defaults(to: 1)
            }

            try db.create(table: "next_actions") { t in
                t.column("id", .text).primaryKey()
                t.column("notionPageId", .text).unique()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("status", .text)
                t.column("projectPageId", .text)
                t.column("projectName", .text)
                t.column("notionLastEdited", .datetime)
                t.column("localUpdatedAt", .datetime).notNull()
                t.column("syncState", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "select_options") { t in
                t.column("databaseKind", .text).notNull()
                t.column("property", .text).notNull()
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.primaryKey(["databaseKind", "property", "name"])
            }

            try db.create(table: "active_timer") { t in
                t.column("id", .integer).primaryKey()
                t.column("timeRecordId", .text).notNull()
                t.column("startedAt", .datetime).notNull()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("nextActionPageId", .text)
            }

            try db.create(table: "sync_cursor") { t in
                t.column("databaseId", .text).primaryKey()
                t.column("lastEditedAt", .datetime)
                t.column("lastSyncedAt", .datetime)
            }
        }

        return migrator
    }
}
