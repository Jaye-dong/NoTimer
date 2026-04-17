import SwiftUI

@main
struct NoTimerApp: App {
    @State private var dependencies = AppDependencies.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
        }
    }
}
