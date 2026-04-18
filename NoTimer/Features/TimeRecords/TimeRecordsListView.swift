import SwiftUI

struct TimeRecordsListView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var records: [TimeRecord] = []
    @State private var query: String = ""
    @State private var errorMessage: String?

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
    }

    private var list: some View {
        List(filtered) { record in
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
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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
            _ = try await deps.pullStrategy.runFullPull()
            reload()
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

#Preview {
    TimeRecordsListView()
        .environment(AppDependencies.bootstrap())
}
