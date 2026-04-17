import SwiftUI

struct TimeRecordsListView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var records: [TimeRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "没有时间记录",
                        systemImage: "list.bullet.rectangle",
                        description: Text("开始计时或手动新增后会显示在这里")
                    )
                } else {
                    List(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title).font(.body)
                            HStack(spacing: 8) {
                                Text(record.startAt, style: .date)
                                if let end = record.endAt {
                                    Text("\(record.startAt, style: .time) – \(end, style: .time)")
                                } else {
                                    Text("进行中").foregroundStyle(.orange)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("时间记录")
        }
        .task { reload() }
    }

    private func reload() {
        records = (try? deps.timeRecords.recent()) ?? []
    }
}

#Preview {
    TimeRecordsListView()
        .environment(AppDependencies.bootstrap())
}
