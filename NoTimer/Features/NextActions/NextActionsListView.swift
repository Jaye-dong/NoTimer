import SwiftUI

struct NextActionsListView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var actions: [NextAction] = []

    var body: some View {
        NavigationStack {
            Group {
                if actions.isEmpty {
                    ContentUnavailableView(
                        "没有下一步行动",
                        systemImage: "checklist",
                        description: Text("M2 里程碑会拉取 Notion 数据填充此列表")
                    )
                } else {
                    List(actions) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.title).font(.body)
                            if let status = action.status {
                                Text(status).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("下一步行动")
        }
        .task { reload() }
    }

    private func reload() {
        actions = (try? deps.nextActions.openActions()) ?? []
    }
}

#Preview {
    NextActionsListView()
        .environment(AppDependencies.bootstrap())
}
