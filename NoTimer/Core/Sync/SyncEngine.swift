import Foundation

/// 组合 PushQueue 和 PullStrategy 跑一轮同步。
///
/// 顺序：Pull → Push → Pull。第一次 pull 保证 schema 新鲜（title 字段、select 选项），
/// 之后 push 本地 pending 到 Notion，最后再 pull 一次把 Notion 自己算的 formula/rollup
/// 以及刚刚 push 进去的记录的服务端 `last_edited_time` 拉回来。
actor SyncEngine {
    struct Summary: Sendable {
        var push: PushQueue.Summary
        var pull: PullStrategy.Summary
    }

    private let pull: PullStrategy
    private let push: PushQueue
    /// 正在跑的 runOnce Task。重入调用（比如 scenePhase 连续切换、下拉刷新期间又被唤起）
    /// 直接 await 同一个 Task，避免多份全量拉取同时把两个库反序列化到内存里。
    private var inFlight: Task<Summary, Error>?

    init(pull: PullStrategy, push: PushQueue) {
        self.pull = pull
        self.push = push
    }

    func runOnce() async throws -> Summary {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task<Summary, Error> { [pull, push] in
            _ = try await pull.runFullPull()
            let pushSummary = try await push.run()
            let pullSummary = try await pull.runFullPull()
            return Summary(push: pushSummary, pull: pullSummary)
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    /// 仅推送（比如 stop 计时后立刻触发），不拉取，失败静默。
    @discardableResult
    func pushOnly() async -> PushQueue.Summary {
        (try? await push.run()) ?? PushQueue.Summary()
    }
}
