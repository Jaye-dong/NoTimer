import BackgroundTasks
import Foundation

/// 把 SyncEngine 接到 BGAppRefreshTask 上，让系统在后台间歇性触发同步。
///
/// 注意：iOS 的后台调度是「尽力而为」，不保证准时也不保证一定执行。
/// 关键路径（停止计时后立刻 push）依然走 fire-and-forget Task，不能只指望这里。
final class BackgroundSyncScheduler: Sendable {
    static let identifier = "com.jayedong.notimer.sync"

    private let syncEngine: SyncEngine

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
    }

    /// 在 app 启动时调一次：注册 task handler。必须在 didFinishLaunching 等价时机。
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.identifier,
            using: nil
        ) { [self] task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    /// 排下一次同步。每次 app 进入后台、或上一次任务完成后调。
    func schedule(after interval: TimeInterval = 30 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("BGTaskScheduler submit failed: \(error)")
            #endif
        }
    }

    private func handle(task: BGAppRefreshTask) {
        // 跑完之后再排下一次 — 后台任务系统按这种「自我延续」模式。
        schedule()

        let work = Task { [syncEngine] in
            _ = try? await syncEngine.runOnce()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
}
