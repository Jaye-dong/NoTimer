import XCTest
@testable import NoTimer

final class TimerControllerTests: XCTestCase {
    private func makeController() throws -> (TimerController, AppDatabase, TimeRecordRepository) {
        let db = try AppDatabase.inMemory()
        let repo = TimeRecordRepository(database: db)
        let controller = TimerController(database: db, timeRecords: repo)
        return (controller, db, repo)
    }

    func testStartInsertsPendingRecordAndActiveTimer() throws {
        let (controller, _, repo) = try makeController()
        XCTAssertNil(controller.current)

        let record = try controller.start(title: "写代码", nextActionPageId: "page-1")
        XCTAssertEqual(controller.current?.timeRecordId, record.id)
        XCTAssertEqual(controller.current?.nextActionPageId, "page-1")

        let fetched = try XCTUnwrap(repo.recent().first)
        XCTAssertEqual(fetched.title, "写代码")
        XCTAssertEqual(fetched.syncState, .pendingPush)
        XCTAssertTrue(fetched.isActive)
    }

    func testStopFinalisesRecord() throws {
        let (controller, _, repo) = try makeController()
        _ = try controller.start(title: "debug", nextActionPageId: nil)
        try controller.stop()

        XCTAssertNil(controller.current)
        let fetched = try XCTUnwrap(repo.recent().first)
        XCTAssertNotNil(fetched.endAt)
        XCTAssertFalse(fetched.isActive)
        XCTAssertEqual(fetched.syncState, .pendingPush)
    }

    func testStartWhileActiveStopsPrevious() throws {
        let (controller, _, repo) = try makeController()
        _ = try controller.start(title: "A")
        _ = try controller.start(title: "B")

        XCTAssertEqual(controller.current?.title, "B")
        let all = try repo.recent()
        XCTAssertEqual(all.count, 2)
        // 先开的应该被 stop（有 endAt），后开的正在计时
        let a = try XCTUnwrap(all.first(where: { $0.title == "A" }))
        let b = try XCTUnwrap(all.first(where: { $0.title == "B" }))
        XCTAssertNotNil(a.endAt)
        XCTAssertNil(b.endAt)
    }

    func testCancelRemovesRecord() throws {
        let (controller, _, repo) = try makeController()
        _ = try controller.start(title: "mistake")
        try controller.cancel()

        XCTAssertNil(controller.current)
        let all = try repo.recent()
        XCTAssertTrue(all.isEmpty, "cancel 应该把整条记录一起删掉")
    }

    func testRestoreRecoversActiveTimerAcrossInstances() throws {
        let db = try AppDatabase.inMemory()
        let repo = TimeRecordRepository(database: db)
        let first = TimerController(database: db, timeRecords: repo)
        _ = try first.start(title: "restore me", nextActionPageId: "p-1")

        let second = TimerController(database: db, timeRecords: repo)
        XCTAssertNil(second.current, "初始为 nil 直到 restore")
        second.restore()
        XCTAssertEqual(second.current?.title, "restore me")
        XCTAssertEqual(second.current?.nextActionPageId, "p-1")
    }
}
