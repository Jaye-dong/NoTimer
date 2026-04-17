import SwiftUI

struct NextActionsListView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var actions: [NextAction] = []
    @State private var query: String = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if actions.isEmpty {
                    ContentUnavailableView(
                        "还没有下一步行动",
                        systemImage: "checklist",
                        description: Text(deps.notionAuth.hasToken
                            ? "下拉刷新以从 Notion 拉取"
                            : "先去设置页配置 Notion 连接")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("下一步行动")
            .searchable(text: $query, prompt: "搜索标题")
            .refreshable { await refresh() }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
            }
        }
        .task { reload() }
    }

    private var list: some View {
        List(filtered) { action in
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.body)
                HStack(spacing: 8) {
                    if let status = action.status, !status.isEmpty {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }
                    if action.syncState == .pendingPush {
                        Label("未同步", systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if action.syncState == .conflict {
                        Label("有冲突", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var filtered: [NextAction] {
        guard !query.isEmpty else { return actions }
        return actions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func reload() {
        do {
            actions = try deps.nextActions.all()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refresh() async {
        errorMessage = nil
        do {
            _ = try await deps.pullStrategy.runFullPull()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NextActionsListView()
        .environment(AppDependencies.bootstrap())
}
