import XCTest
@testable import NoTimer

final class AppDatabaseTests: XCTestCase {
    func testInMemorySetupAndInsert() throws {
        let db = try AppDatabase.inMemory()
        let repo = TimeRecordRepository(database: db)

        let record = TimeRecord.new(title: "测试", startAt: Date())
        try repo.insert(record)

        let recent = try repo.recent()
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.title, "测试")
        XCTAssertEqual(recent.first?.syncState, .pendingPush)
    }

    func testActiveTimerSingleton() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            var a = ActiveTimer(
                timeRecordId: "rec-1",
                startedAt: Date(),
                title: "写代码",
                nextActionPageId: nil
            )
            try a.save(db)
        }
        let fetched = try db.writer.read { db in
            try ActiveTimer.fetchOne(db, key: ActiveTimer.singletonId)
        }
        XCTAssertEqual(fetched?.timeRecordId, "rec-1")
    }
}
