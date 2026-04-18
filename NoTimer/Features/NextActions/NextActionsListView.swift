import SwiftUI

struct NextActionsListView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var actions: [NextAction] = []
    @State private var query: String = ""
    @State private var errorMessage: String?
    @State private var startedJustNow: String?

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
            .overlay(alignment: .bottom) { overlayMessage }
        }
        .task { reload() }
    }

    private var list: some View {
        List(filtered) { action in
            Button {
                start(action: action)
            } label: {
                row(action)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
    }

    private func row(_ action: NextAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isActive(action) ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(isActive(action) ? Color.orange : Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title.isEmpty ? "（无标题）" : action.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

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
            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var overlayMessage: some View {
        if let startedJustNow {
            Label("已开始：\(startedJustNow)", systemImage: "timer")
                .font(.footnote)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding()
                .transition(.opacity)
        } else if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
    }

    private func isActive(_ action: NextAction) -> Bool {
        guard let current = deps.timerController.current,
              let pageId = action.notionPageId else { return false }
        return current.nextActionPageId == pageId
    }

    private func start(action: NextAction) {
        do {
            try deps.timerController.start(
                title: action.title,
                nextActionPageId: action.notionPageId
            )
            errorMessage = nil
            startedJustNow = action.title
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { startedJustNow = nil }
            }
        } catch {
            errorMessage = error.localizedDescription
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
            let summary = try await deps.syncEngine.runOnce()
            reload()
            if let first = summary.push.firstError {
                errorMessage = "部分推送失败：\(first)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NextActionsListView()
        .environment(AppDependencies.bootstrap())
}
