import SwiftUI

struct HomeView: View {
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "timer")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.tint)
                Text("No Active Timer")
                    .font(.title2.weight(.semibold))
                Text("M3 里程碑将实装：选择下一步行动 → 一键开始。当前为项目骨架。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                if !deps.notionAuth.hasToken {
                    ContentUnavailableView(
                        "未连接 Notion",
                        systemImage: "link.badge.plus",
                        description: Text("在设置里粘贴 Integration Token 完成连接")
                    )
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("NoTimer")
        }
    }
}

#Preview {
    HomeView()
        .environment(AppDependencies.bootstrap())
}
