import SwiftUI
import WidgetKit

/// 主屏 widget：展示当前正在计时的任务名 + 已计时秒表。没有计时时显示占位。
/// 数据从 App Group UserDefaults 读，TimerController 在 start/stop/cancel 时已经写过。
struct CurrentTimerWidget: Widget {
    let kind: String = "CurrentTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerProvider()) { entry in
            CurrentTimerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("当前计时")
        .description("展示正在进行的计时任务和已计时时长。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimerEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedTimerSnapshot?
}

struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: Date(), snapshot: SharedTimerSnapshot(
            timeRecordId: "preview",
            title: "写代码",
            startedAt: Date().addingTimeInterval(-25 * 60),
            nextActionPageId: nil
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(TimerEntry(date: Date(), snapshot: SharedTimerStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        // 单个 entry，秒表用 Text(timerInterval:) 自动走时；
        // 30 分钟后让系统重新刷一次（万一应用已挂掉，避免显示陈旧任务）。
        let entry = TimerEntry(date: Date(), snapshot: SharedTimerStore.read())
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct CurrentTimerWidgetView: View {
    let entry: TimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            active(snapshot)
        } else {
            idle
        }
    }

    private func active(_ snapshot: SharedTimerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("正在计时", systemImage: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)

            Text(snapshot.title.isEmpty ? "未命名任务" : snapshot.title)
                .font(family == .systemMedium ? .headline : .subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text(timerInterval: snapshot.startedAt...Date.distantFuture,
                 countsDown: false,
                 showsHours: true)
                .font((family == .systemMedium ? .system(size: 32) : .system(size: 24))
                      .weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.tint)

            Text("开始于 \(snapshot.startedAt, format: .dateTime.hour().minute())")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("没有进行中的计时")
                .font(.subheadline.weight(.medium))
            Text("点击进入 NoTimer 开始")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview(as: .systemSmall) {
    CurrentTimerWidget()
} timeline: {
    TimerEntry(date: .now, snapshot: SharedTimerSnapshot(
        timeRecordId: "1",
        title: "写代码",
        startedAt: .now.addingTimeInterval(-1500),
        nextActionPageId: nil
    ))
    TimerEntry(date: .now, snapshot: nil)
}
