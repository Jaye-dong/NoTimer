import ActivityKit
import SwiftUI
import WidgetKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.accentColor.opacity(0.1))
                .activitySystemActionForegroundColor(Color.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...Date.distantFuture,
                         countsDown: false,
                         showsHours: true)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.tint)
                        .frame(alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(displayTitle(context.state))
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("开始于 \(context.state.startedAt, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...Date.distantFuture,
                     countsDown: false,
                     showsHours: false)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tint)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
            }
            .keylineTint(.accentColor)
        }
    }

    private func displayTitle(_ state: TimerAttributes.TimerState) -> String {
        state.title.isEmpty ? "未命名任务" : state.title
    }
}

private struct LockScreenView: View {
    let state: TimerAttributes.TimerState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.title)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title.isEmpty ? "未命名任务" : state.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(timerInterval: state.startedAt...Date.distantFuture,
                         countsDown: false,
                         showsHours: true)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.tint)
                    Text("开始于 \(state.startedAt, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
