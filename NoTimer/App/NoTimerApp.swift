import SwiftUI

@main
struct NoTimerApp: App {
    @State private var dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let deps = AppDependencies.bootstrap()
        self._dependencies = State(initialValue: deps)
        // BGTask handler 必须在 app 启动早期注册，放 init 里最稳。
        deps.backgroundSync.register()
        deps.notifications.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // 前台激活也跑一次同步，BGTask 不可靠
                Task { _ = try? await dependencies.syncEngine.runOnce() }
            case .background:
                dependencies.backgroundSync.schedule()
            default:
                break
            }
        }
    }
}
