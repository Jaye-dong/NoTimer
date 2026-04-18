import ActivityKit
import Foundation

/// Live Activity 的 attributes — 同时被 app 与 Widget Extension 编译。
///
/// - `timerId` 放在 attributes 里（不可变）便于区分多个 activity 实例；
/// - 可变状态只含 `title` / `startedAt` / `nextActionPageId`。秒表读数用
///   `Text(timerInterval:…)` 系统组件渲染，不需要每秒推送更新。
struct TimerAttributes: ActivityAttributes {
    public typealias ContentState = TimerAttributes.TimerState

    public struct TimerState: Codable, Hashable {
        var title: String
        var startedAt: Date
        var nextActionPageId: String?

        public init(title: String, startedAt: Date, nextActionPageId: String?) {
            self.title = title
            self.startedAt = startedAt
            self.nextActionPageId = nextActionPageId
        }
    }

    var timerId: String

    public init(timerId: String) {
        self.timerId = timerId
    }
}
