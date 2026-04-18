import ActivityKit
import Foundation

/// 包裹 ActivityKit，让 TimerController 可以用简单的 start / end 控制
/// 锁屏与灵动岛上的 Live Activity。
///
/// 设计要点：
/// - 一次只跟踪一个 Activity，启新的前先结束旧的，避免上屏重复
/// - 方法是 nonisolated 的 sync，但内部派发异步 end — TimerController
///   可以同步调用，不阻塞 UI
@MainActor
final class LiveActivityManager {
    private var current: Activity<TimerAttributes>?

    /// 开启一个 Live Activity。如果用户在系统设置里禁用了或当前没有权限，静默忽略。
    func start(title: String, startedAt: Date, nextActionPageId: String?, timerId: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()  // 保证单例

        let attributes = TimerAttributes(timerId: timerId)
        let state = TimerAttributes.TimerState(
            title: title,
            startedAt: startedAt,
            nextActionPageId: nextActionPageId
        )
        do {
            current = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("LiveActivity start failed: \(error)")
            #endif
        }
    }

    /// 结束所有进行中的 TimerAttributes activity（包括本对象跟踪外的孤儿）。
    func end() {
        let tracked = current
        current = nil
        Task {
            if let tracked {
                await tracked.end(nil, dismissalPolicy: .immediate)
            }
            for activity in Activity<TimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
