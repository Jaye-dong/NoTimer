import SwiftUI

struct TimeRecordsListView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var records: [TimeRecord] = []
    @State private var query: String = ""
    @State private var errorMessage: String?
    @State private var editing: TimeRecordEditView.Mode?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "还没有时间记录",
                        systemImage: "list.bullet.rectangle",
                        description: Text(deps.notionAuth.hasToken
                            ? "下拉刷新以从 Notion 拉取"
                            : "先去设置页配置 Notion 连接")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("时间记录")
            .searchable(text: $query, prompt: "搜索标题")
            .refreshable { await refresh() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = .create
                    } label: {
                        Label("补录", systemImage: "plus")
                    }
                }
            }
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
        .onChange(of: deps.timerController.current?.timeRecordId) { _, _ in
            reload()
        }
        .sheet(item: Binding(
            get: { editing.map(EditingSheet.init) },
            set: { editing = $0?.mode }
        )) { wrapper in
            TimeRecordEditView(mode: wrapper.mode)
                .onDisappear { reload() }
        }
    }

    private var list: some View {
        List {
            ForEach(filtered) { record in
                Button {
                    // 进行中的不允许这里编辑，先在 Home 页停止。
                    guard record.endAt != nil else { return }
                    editing = .edit(record)
                } label: {
                    row(record)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if record.endAt != nil {
                        Button(role: .destructive) {
                            delete(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func row(_ record: TimeRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title.isEmpty ? "（无标题）" : record.title)
                .font(.body)

            HStack(spacing: 8) {
                Text(record.startAt, format: .dateTime.month().day().hour().minute())
                if let end = record.endAt {
                    Text("→ \(end, format: .dateTime.hour().minute())")
                    if let dur = record.duration {
                        Text(Self.formatDuration(dur))
                            .foregroundStyle(.tint)
                    }
                } else {
                    Text("进行中")
                        .foregroundStyle(.orange)
                }
                if let cat = record.category, !cat.isEmpty {
                    Text(cat)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
                if record.syncState == .pendingPush {
                    Image(systemName: "arrow.up.circle")
                        .foregroundStyle(.orange)
                } else if record.syncState == .conflict {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func delete(_ record: TimeRecord) {
        do {
            try deps.timeRecords.delete(id: record.id)
            Task { await deps.syncEngine.pushOnly() }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var filtered: [TimeRecord] {
        guard !query.isEmpty else { return records }
        return records.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func reload() {
        do {
            records = try deps.timeRecords.recent(limit: 500)
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

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMin = max(0, Int(seconds / 60))
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

/// `.sheet(item:)` 需要 Identifiable；Mode 是带关联值的 enum 不天然满足，包一层。
private struct EditingSheet: Identifiable {
    let mode: TimeRecordEditView.Mode
    var id: String {
        switch mode {
        case .create: return "create"
        case let .edit(record): return "edit-\(record.id)"
        }
    }
}

#Preview {
    TimeRecordsListView()
        .environment(AppDependencies.bootstrap())
}
