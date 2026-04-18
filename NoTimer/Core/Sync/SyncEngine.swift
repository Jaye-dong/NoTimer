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

    init(pull: PullStrategy, push: PushQueue) {
        self.pull = pull
        self.push = push
    }

    func runOnce() async throws -> Summary {
        _ = try await pull.runFullPull()
        let pushSummary = try await push.run()
        let pullSummary = try await pull.runFullPull()
        return Summary(push: pushSummary, pull: pullSummary)
    }

    /// 仅推送（比如 stop 计时后立刻触发），不拉取，失败静默。
    @discardableResult
    func pushOnly() async -> PushQueue.Summary {
        (try? await push.run()) ?? PushQueue.Summary()
    }
}
