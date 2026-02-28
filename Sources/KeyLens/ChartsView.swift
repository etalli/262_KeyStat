import SwiftUI
import Charts

// MARK: - Chart data types

struct TopKeyEntry: Identifiable {
    let id: String
    let key: String
    let count: Int
    init(_ t: (key: String, count: Int)) { id = t.key; key = t.key; count = t.count }
}

struct DailyTotalEntry: Identifiable {
    let id: String
    let date: String
    let total: Int
    init(_ t: (date: String, total: Int)) { id = t.date; date = t.date; total = t.total }
}

struct CategoryEntry: Identifiable {
    var id: String { type.rawValue }
    let type: KeyType
    let count: Int
    init(_ t: (type: KeyType, count: Int)) { type = t.type; count = t.count }
}

struct DailyKeyEntry: Identifiable {
    let id = UUID()
    let date: String
    let key: String
    let count: Int
    init(_ t: (date: String, key: String, count: Int)) { date = t.date; key = t.key; count = t.count }
}

struct ShortcutEntry: Identifiable {
    let id: String
    let key: String
    let count: Int
    init(_ t: (key: String, count: Int)) { id = t.key; key = t.key; count = t.count }
}

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Keyboard Heatmap") { KeyboardHeatmapView(counts: model.keyCounts) }
                chartSection("Top 20 Keys — All Time") { topKeysChart }
                chartSection("Daily Totals") { dailyTotalsChart }
                chartSection("Key Categories") { categoryChart }
                chartSection("Top 10 Keys per Day") { perDayChart }
                chartSection("⌘ Keyboard Shortcuts") { shortcutsChart }
            }
            .padding(24)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func chartSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    // MARK: - Chart 1: Top 20 Keys (horizontal bar, color-coded)

    @ViewBuilder
    private var topKeysChart: some View {
        if model.topKeys.isEmpty {
            emptyState
        } else {
            let keyOrder = model.topKeys.map(\.key)
            VStack(alignment: .leading, spacing: 6) {
                Chart(model.topKeys) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Key", item.key)
                    )
                    .foregroundStyle(KeyType.classify(item.key).color)
                    .cornerRadius(3)
                }
                .chartYScale(domain: keyOrder.reversed())
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topKeys.count * 26 + 24))

                // カラーレジェンド
                let presentTypes = Set(model.topKeys.map { KeyType.classify($0.key) })
                HStack(spacing: 14) {
                    ForEach(KeyType.allCases, id: \.self) { type in
                        if presentTypes.contains(type) {
                            HStack(spacing: 4) {
                                Circle().fill(type.color).frame(width: 8, height: 8)
                                Text(type.label).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chart 2: Daily Totals (line chart)

    @ViewBuilder
    private var dailyTotalsChart: some View {
        if model.dailyTotals.isEmpty {
            emptyState
        } else if model.dailyTotals.count == 1 {
            // 1点のみの場合は BarMark で代替
            Chart(model.dailyTotals) { item in
                BarMark(x: .value("Date", item.date), y: .value("Total", item.total))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyTotals) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.blue.opacity(0.12))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.blue)
                .annotation(position: .top, spacing: 4) {
                    Text(item.total.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Chart 3: Key Categories (doughnut / stacked bar)

    @ViewBuilder
    private var categoryChart: some View {
        if model.categories.isEmpty {
            emptyState
        } else if #available(macOS 14.0, *) {
            donutChart
        } else {
            stackedBarCategories
        }
    }

    @available(macOS 14.0, *)
    private var donutChart: some View {
        HStack(alignment: .center, spacing: 28) {
            Chart(model.categories) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.52),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(item.type.color)
            }
            .chartLegend(.hidden)
            .frame(width: 180, height: 180)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.categories) { item in
                    HStack(spacing: 8) {
                        Circle().fill(item.type.color).frame(width: 10, height: 10)
                        Text(item.type.label).font(.callout)
                        Spacer()
                        Text(item.count.formatted())
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 160)
                }
            }
        }
    }

    // macOS 13 フォールバック: 横積みバー + レジェンド
    private var stackedBarCategories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(model.categories) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Category", "")
                )
                .foregroundStyle(item.type.color)
            }
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .frame(height: 40)

            HStack(spacing: 14) {
                ForEach(model.categories) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.type.color).frame(width: 8, height: 8)
                        Text("\(item.type.label) \(item.count.formatted())")
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Chart 4: Top 10 keys per day (grouped bar)

    @ViewBuilder
    private var perDayChart: some View {
        if model.perDayKeys.isEmpty {
            emptyState
        } else {
            let keyOrder = model.perDayKeys
                .reduce(into: [String: Int]()) { $0[$1.key, default: 0] += $1.count }
                .sorted { $0.value > $1.value }
                .map(\.key)

            Chart(model.perDayKeys) { item in
                BarMark(
                    x: .value("Key", item.key),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(by: .value("Date", item.date))
                .position(by: .value("Date", item.date))
                .cornerRadius(3)
            }
            .chartXScale(domain: keyOrder)
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
        }
    }

    // MARK: - Chart 5: ⌘ Keyboard Shortcuts (horizontal bar)

    @ViewBuilder
    private var shortcutsChart: some View {
        if model.shortcuts.isEmpty {
            emptyState
        } else {
            let keyOrder = model.shortcuts.map(\.key)
            Chart(model.shortcuts) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Shortcut", item.key)
                )
                .foregroundStyle(shortcutColor(item.key))
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: keyOrder.reversed())
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.shortcuts.count * 26 + 24))
        }
    }

    private func shortcutColor(_ key: String) -> Color {
        switch key {
        case "⌘c": return .green
        case "⌘v": return .blue
        case "⌘x": return .orange
        case "⌘z": return .purple
        default:    return .teal
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("(no data yet)")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}
