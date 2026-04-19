import Foundation

/// 主 app 与 Widget extension 共享的「当前计时」快照。
/// 通过 App Group UserDefaults 存一个 JSON 字符串，两端进程都能读写。
///
/// Widget 进程没法访问主 app 的内存或 GRDB（共享 SQLite 也行但成本高），
/// 这里走 UserDefaults 已经够用 — 只在 start/stop/cancel 这种少量事件时写。
struct SharedTimerSnapshot: Codable, Equatable, Sendable {
    var timeRecordId: String
    var title: String
    var startedAt: Date
    var nextActionPageId: String?
}

enum SharedTimerStore {
    static let appGroupId = "group.com.jayedong.notimer"
    private static let key = "currentTimer.snapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func read() -> SharedTimerSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedTimerSnapshot.self, from: data)
    }

    static func write(_ snapshot: SharedTimerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
