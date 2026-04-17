import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("计时", systemImage: "timer") }

            NextActionsListView()
                .tabItem { Label("行动", systemImage: "checklist") }

            TimeRecordsListView()
                .tabItem { Label("记录", systemImage: "list.bullet.rectangle") }

            StatsView()
                .tabItem { Label("统计", systemImage: "chart.bar.xaxis") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .environment(AppDependencies.bootstrap())
}
