import SwiftUI

struct HomeView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let current = deps.timerController.current {
                    activeView(current)
                } else {
                    idleView
                }
            }
            .navigationTitle("NoTimer")
            .animation(.easeInOut(duration: 0.2), value: deps.timerController.current?.timeRecordId)
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
    }

    // MARK: - Active

    private func activeView(_ active: ActiveTimer) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(active.title.isEmpty ? "未命名任务" : active.title)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(active.startedAt)
                Text(elapsed.clockString)
                    .font(.system(size: 80, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
            }

            Text("开始于 \(active.startedAt, format: .dateTime.hour().minute())")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 16) {
                Button(role: .cancel) {
                    tryAction { try deps.timerController.cancel() }
                } label: {
                    Label("放弃", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    tryAction { try deps.timerController.stop() }
                } label: {
                    Label("停止", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.tint)
            Text("没有进行中的计时")
                .font(.title3.weight(.medium))
            Text("在下一步行动里点击任意条目开始计时")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical)

            Button {
                tryAction {
                    try deps.timerController.start(title: "快速计时")
                }
            } label: {
                Label("快速开始计时", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            if !deps.notionAuth.hasToken {
                ContentUnavailableView(
                    "未连接 Notion",
                    systemImage: "link.badge.plus",
                    description: Text("去设置页配置连接以启用同步")
                )
                .padding(.top)
            }

            Spacer()
        }
    }

    private func tryAction(_ work: () throws -> Void) {
        do {
            try work()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    HomeView()
        .environment(AppDependencies.bootstrap())
}
