import Foundation
import GRDB
import Observation

/// 计时器单例状态机。一次只允许一个活跃计时，开启新的会自动停止当前的。
///
/// 设计要点：
/// - UI 直接观察 `current` 属性即可（@Observable + @MainActor）
/// - 所有 DB 写入都用同步 GRDB 调用，保证 start/stop 返回时已落盘
/// - Live Activity 的启停会在 M3b 里挂到 `start` / `stop` 里面
@Observable
final class TimerController {
    private(set) var current: ActiveTimer?

    private let database: AppDatabase
    private let timeRecords: TimeRecordRepository

    init(database: AppDatabase, timeRecords: TimeRecordRepository) {
        self.database = database
        self.timeRecords = timeRecords
    }

    /// 读取 `active_timer` 单例恢复 UI 状态。app 启动时调用一次。
    func restore() {
        current = try? timeRecords.activeTimer()
    }

    /// 开始新的计时。如果已有活跃计时，先停止它。
    @discardableResult
    func start(title: String, nextActionPageId: String? = nil, category: String? = nil) throws -> TimeRecord {
        if current != nil {
            try stop()
        }

        let now = Date()
        let record = TimeRecord.new(
            title: title,
            startAt: now,
            nextActionPageId: nextActionPageId,
            category: category
        )
        let active = ActiveTimer(
            timeRecordId: record.id,
            startedAt: now,
            title: title,
            nextActionPageId: nextActionPageId
        )

        try database.writer.write { db in
            var inserted = record
            try inserted.insert(db)
            var savedActive = active
            try savedActive.save(db)
        }

        current = active
        return record
    }

    /// 停止当前计时，把 end_at 写入关联的 TimeRecord 并清掉 active_timer。
    func stop() throws {
        guard let current else { return }
        let now = Date()

        try database.writer.write { db in
            if var record = try TimeRecord.fetchOne(db, key: current.timeRecordId) {
                record.endAt = now
                record.localUpdatedAt = now
                record.syncState = .pendingPush
                try record.update(db)
            }
            _ = try ActiveTimer.deleteOne(db, key: ActiveTimer.singletonId)
        }

        self.current = nil
    }

    /// 放弃当前计时（不保留记录）。
    func cancel() throws {
        guard let current else { return }
        try database.writer.write { db in
            _ = try TimeRecord.deleteOne(db, key: current.timeRecordId)
            _ = try ActiveTimer.deleteOne(db, key: ActiveTimer.singletonId)
        }
        self.current = nil
    }

    /// 已流逝秒数（若无活跃计时返回 0）。UI 渲染时从 TimelineView 里算，不要依赖此值做刷新。
    func elapsed(at date: Date = Date()) -> TimeInterval {
        guard let current else { return 0 }
        return date.timeIntervalSince(current.startedAt)
    }
}
