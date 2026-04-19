import Foundation
import Observation

/// 统计页的数据聚合。按选中时间段（日/周/月）把已完成的 TimeRecord 汇总成：
/// - 总时长
/// - 按分类的小计（饼图/列表展示用）
/// - 按日期桶 × 分类的分片（堆叠柱状图用）
///
/// 只统计 endAt 非空的记录。分类缺失归到「未分类」。时区走 Calendar.current。
@Observable
@MainActor
final class StatsViewModel {
    enum Range: CaseIterable, Identifiable {
        case day, week, month
        var id: Self { self }
        var label: String {
            switch self {
            case .day: "日"
            case .week: "周"
            case .month: "月"
            }
        }
    }

    struct CategorySummary: Identifiable, Sendable {
        var id: String { name }
        var name: String
        var hours: Double
    }

    struct Bucket: Identifiable, Sendable {
        var id: Date { start }
        var start: Date
        var slices: [CategorySummary]
    }

    var range: Range = .day {
        didSet {
            if range != oldValue {
                offset = 0
                reload()
            }
        }
    }
    /// 相对当前时段的偏移：0=本期，-1=上期，1=下期（0 时右箭头禁用）
    private(set) var offset: Int = 0
    private(set) var totalHours: Double = 0
    private(set) var categoryTotals: [CategorySummary] = []
    private(set) var buckets: [Bucket] = []
    private(set) var interval: DateInterval = DateInterval(start: Date(), end: Date())
    /// 分类名 → Notion 侧 color token（"blue"/"purple"/"yellow"/...）。来自缓存的 select_options。
    /// 本地兜底名（「未分类」）不会出现在这里，由调用方自行兜底。
    private(set) var categoryColorTokens: [String: String] = [:]

    private let timeRecords: TimeRecordRepository
    private let selectOptions: SelectOptionRepository?
    private let unknownCategory = "未分类"

    init(timeRecords: TimeRecordRepository, selectOptions: SelectOptionRepository? = nil) {
        self.timeRecords = timeRecords
        self.selectOptions = selectOptions
    }

    var canStepForward: Bool { offset < 0 }

    func stepBackward() {
        offset -= 1
        reload()
    }

    func stepForward() {
        guard canStepForward else { return }
        offset += 1
        reload()
    }

    func resetToCurrent() {
        guard offset != 0 else { return }
        offset = 0
        reload()
    }

    func reload(now: Date = Date()) {
        let calendar = Calendar.current
        interval = Self.interval(for: range, offset: offset, now: now, calendar: calendar)

        let recordsInRange: [TimeRecord]
        do {
            recordsInRange = try timeRecords.completed(
                overlapping: interval.start,
                and: interval.end
            )
        } catch {
            recordsInRange = []
        }

        totalHours = recordsInRange.reduce(0) { acc, r in
            acc + ((r.duration ?? 0) / 3600)
        }

        var byCategory: [String: Double] = [:]
        for record in recordsInRange {
            let name = (record.category?.isEmpty == false) ? record.category! : unknownCategory
            byCategory[name, default: 0] += (record.duration ?? 0) / 3600
        }
        categoryTotals = byCategory
            .map { CategorySummary(name: $0.key, hours: $0.value) }
            .sorted { $0.hours > $1.hours }

        buckets = Self.buildBuckets(
            range: range,
            interval: interval,
            calendar: calendar,
            records: recordsInRange,
            unknownCategory: unknownCategory
        )

        if let selectOptions {
            let opts = (try? selectOptions.options(
                kind: .timeRecords,
                property: NotionFieldNames.TimeRecord.category
            )) ?? []
            categoryColorTokens = Dictionary(
                uniqueKeysWithValues: opts.compactMap { opt in
                    opt.color.map { (opt.name, $0) }
                }
            )
        }
    }

    var bucketUnit: Calendar.Component {
        range == .day ? .hour : .day
    }

    // MARK: - Static helpers (pure, testable)

    static func interval(for range: Range, offset: Int, now: Date, calendar: Calendar) -> DateInterval {
        switch range {
        case .day:
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: offset, to: today)!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .week:
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
                ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeekStart)!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return DateInterval(start: start, end: end)
        case .month:
            let thisMonthStart = calendar.dateInterval(of: .month, for: now)?.start
                ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .month, value: offset, to: thisMonthStart)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        }
    }

    /// 把 records 按 (桶起点, 分类) 聚合。桶起点：日视图每小时、周/月视图每天。
    /// 跨桶的 record（开始和结束落在不同桶里）按时长按比例拆分到各自的桶。
    static func buildBuckets(
        range: Range,
        interval: DateInterval,
        calendar: Calendar,
        records: [TimeRecord],
        unknownCategory: String
    ) -> [Bucket] {
        let unit: Calendar.Component = range == .day ? .hour : .day
        var buckets: [Date: [String: Double]] = [:]

        // 预生成空桶，保证图表有连续 x 轴
        var cursor = interval.start
        while cursor < interval.end {
            buckets[cursor] = [:]
            guard let next = calendar.date(byAdding: unit, value: 1, to: cursor) else { break }
            cursor = next
        }

        for record in records {
            guard let end = record.endAt else { continue }
            let name = (record.category?.isEmpty == false) ? record.category! : unknownCategory
            let clampedStart = max(record.startAt, interval.start)
            let clampedEnd = min(end, interval.end)
            guard clampedEnd > clampedStart else { continue }

            // 按 unit 步进，把该 record 的时长按小时数摊到每个桶
            var segStart = clampedStart
            while segStart < clampedEnd {
                let bucketStart = floor(segStart, to: unit, calendar: calendar)
                let bucketEnd = calendar.date(byAdding: unit, value: 1, to: bucketStart)!
                let segEnd = min(clampedEnd, bucketEnd)
                let hours = segEnd.timeIntervalSince(segStart) / 3600
                buckets[bucketStart, default: [:]][name, default: 0] += hours
                segStart = segEnd
            }
        }

        return buckets.keys.sorted().map { start in
            let slices = (buckets[start] ?? [:])
                .map { CategorySummary(name: $0.key, hours: $0.value) }
                .sorted { $0.hours > $1.hours }
            return Bucket(start: start, slices: slices)
        }
    }

    private static func floor(_ date: Date, to unit: Calendar.Component, calendar: Calendar) -> Date {
        switch unit {
        case .hour:
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: comps) ?? date
        case .day:
            return calendar.startOfDay(for: date)
        default:
            return date
        }
    }
}
