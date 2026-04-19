import Charts
import SwiftUI

struct StatsView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var viewModel: StatsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("统计")
        }
        .task {
            if viewModel == nil {
                let vm = StatsViewModel(
                    timeRecords: deps.timeRecords,
                    selectOptions: deps.selectOptions
                )
                vm.reload()
                viewModel = vm
            }
        }
        .onChange(of: deps.timerController.current?.timeRecordId) { _, _ in
            viewModel?.reload()
        }
    }

    @ViewBuilder
    private func content(viewModel: StatsViewModel) -> some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("范围", selection: $vm.range) {
                    ForEach(StatsViewModel.Range.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                stepper(vm)
                summary(vm)

                if vm.totalHours > 0 {
                    let p = palette(for: vm)
                    stackedChart(vm, palette: p)
                    pieChart(vm, palette: p)
                    categoryList(vm, palette: p)
                } else {
                    ContentUnavailableView(
                        "这个时间段还没有记录",
                        systemImage: "chart.bar.xaxis",
                        description: Text("停止计时后这里会自动聚合")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.vertical)
        }
        .refreshable { vm.reload() }
    }

    private func stepper(_ vm: StatsViewModel) -> some View {
        HStack {
            Button {
                vm.stepBackward()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("上一\(vm.range.label)")

            Spacer()

            Button {
                vm.resetToCurrent()
            } label: {
                Text(rangeTitle(vm))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)
            .disabled(vm.offset == 0)

            Spacer()

            Button {
                vm.stepForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(!vm.canStepForward)
            .accessibilityLabel("下一\(vm.range.label)")
        }
        .padding(.horizontal)
    }

    private func summary(_ vm: StatsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(offsetLabel(vm))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatHours(vm.totalHours))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func offsetLabel(_ vm: StatsViewModel) -> String {
        switch vm.offset {
        case 0:   return "本\(vm.range.label)"
        case -1:  return "上\(vm.range.label)"
        case let n: return "\(-n) \(vm.range.label)前"
        }
    }

    private func stackedChart(_ vm: StatsViewModel, palette: CategoryPalette) -> some View {
        Chart {
            ForEach(vm.buckets) { bucket in
                ForEach(bucket.slices) { slice in
                    BarMark(
                        x: .value("日期", bucket.start, unit: vm.bucketUnit),
                        y: .value("小时", slice.hours)
                    )
                    .foregroundStyle(by: .value("分类", slice.name))
                }
            }
        }
        .chartForegroundStyleScale(domain: palette.domain, range: palette.range)
        .chartXAxis { xAxis(for: vm.range) }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 220)
        .padding(.horizontal)
    }

    private func pieChart(_ vm: StatsViewModel, palette: CategoryPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("占比")
                .font(.headline)
                .padding(.horizontal)

            Chart(vm.categoryTotals) { row in
                SectorMark(
                    angle: .value("小时", row.hours),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("分类", row.name))
            }
            .chartForegroundStyleScale(domain: palette.domain, range: palette.range)
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 240)
            .padding(.horizontal)
        }
    }

    @AxisContentBuilder
    private func xAxis(for range: StatsViewModel.Range) -> some AxisContent {
        switch range {
        case .day:
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                AxisGridLine()
            }
        case .week:
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                AxisGridLine()
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                AxisValueLabel(format: .dateTime.day())
                AxisGridLine()
            }
        }
    }

    private func categoryList(_ vm: StatsViewModel, palette: CategoryPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("按分类")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(vm.categoryTotals) { row in
                    HStack {
                        Circle()
                            .fill(palette.color(for: row.name))
                            .frame(width: 10, height: 10)
                        Text(row.name)
                        Spacer()
                        Text(formatHours(row.hours))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(percentString(row.hours, total: vm.totalHours))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    if row.id != vm.categoryTotals.last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Formatting

    private func rangeTitle(_ vm: StatsViewModel) -> String {
        let start = vm.interval.start
        switch vm.range {
        case .day:
            return start.formatted(date: .complete, time: .omitted)
        case .week:
            let endIncl = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? vm.interval.end
            return start.formatted(.dateTime.month().day()) + " – " + endIncl.formatted(.dateTime.month().day())
        case .month:
            return start.formatted(.dateTime.year().month(.wide))
        }
    }

    private func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m) 分钟" }
        if m == 0 { return "\(h) 小时" }
        return "\(h) 小时 \(m) 分钟"
    }

    private func percentString(_ hours: Double, total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = Int((hours / total * 100).rounded())
        return "\(pct)%"
    }

    private func palette(for vm: StatsViewModel) -> CategoryPalette {
        CategoryPalette(
            names: vm.categoryTotals.map(\.name),
            notionColorTokens: vm.categoryColorTokens
        )
    }
}

/// 把分类名映射到颜色。优先用 Notion 缓存里的 color token（和 Notion 网页上显示的色保持一致），
/// 未命中的（例如本地兜底「未分类」）按稳定顺序分配默认色。柱状图/饼图/列表共用同一份色板。
struct CategoryPalette {
    /// Notion select option 的 color token → SwiftUI Color。
    /// 这里用 Notion 网页上 tag 的浅色背景作为参考（马卡龙/pastel 风），
    /// 和 Notion 看起来保持一致。
    static func color(forNotionToken token: String) -> Color {
        switch token {
        case "blue":    return Color(red: 0x82/255, green: 0xB5/255, blue: 0xD2/255)
        case "purple":  return Color(red: 0xC0/255, green: 0xA3/255, blue: 0xD4/255)
        case "pink":    return Color(red: 0xE7/255, green: 0xB4/255, blue: 0xCC/255)
        case "red":     return Color(red: 0xF2/255, green: 0xAE/255, blue: 0xA5/255)
        case "orange":  return Color(red: 0xF2/255, green: 0xC1/255, blue: 0x8C/255)
        case "yellow":  return Color(red: 0xF2/255, green: 0xD8/255, blue: 0x8F/255)
        case "green":   return Color(red: 0xA2/255, green: 0xCE/255, blue: 0xA2/255)
        case "brown":   return Color(red: 0xC6/255, green: 0xAA/255, blue: 0x92/255)
        case "gray":    return Color(red: 0xC6/255, green: 0xC4/255, blue: 0xC0/255)
        case "default": return Color(red: 0xD2/255, green: 0xD1/255, blue: 0xCD/255)
        default:        return Color(red: 0xC6/255, green: 0xC4/255, blue: 0xC0/255)
        }
    }

    /// 没匹配到 Notion token 时的兜底序列（同一套 pastel，顺序参考用户 Notion 分类截图）。
    static let fallback: [Color] = [
        color(forNotionToken: "gray"),
        color(forNotionToken: "blue"),
        color(forNotionToken: "purple"),
        color(forNotionToken: "yellow"),
        color(forNotionToken: "pink"),
        color(forNotionToken: "orange"),
        color(forNotionToken: "green"),
        color(forNotionToken: "brown"),
        color(forNotionToken: "red"),
        color(forNotionToken: "default")
    ]

    let domain: [String]
    let range: [Color]
    private let map: [String: Color]

    init(names: [String], notionColorTokens: [String: String] = [:]) {
        self.domain = names
        var fallbackIdx = 0
        let mapped: [(String, Color)] = names.map { name in
            if let token = notionColorTokens[name] {
                return (name, Self.color(forNotionToken: token))
            }
            let c = Self.fallback[fallbackIdx % Self.fallback.count]
            fallbackIdx += 1
            return (name, c)
        }
        self.range = mapped.map(\.1)
        self.map = Dictionary(uniqueKeysWithValues: mapped)
    }

    func color(for name: String) -> Color {
        map[name] ?? .gray
    }
}

#Preview {
    StatsView()
        .environment(AppDependencies.bootstrap())
}
