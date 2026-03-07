import SwiftUI
import Charts
import KeyLensCore

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

struct BigramEntry: Identifiable {
    let id: String
    let pair: String
    let count: Int
    init(_ t: (pair: String, count: Int)) { id = t.pair; pair = t.pair; count = t.count }
}

struct AppEntry: Identifiable {
    let id: String
    let app: String
    let count: Int
    init(_ t: (app: String, count: Int)) { id = t.app; app = t.app; count = t.count }
}

struct AppErgScoreEntry: Identifiable {
    let id: String
    let app: String
    let score: Double
    let keystrokes: Int
    init(_ t: (app: String, score: Double, keystrokes: Int)) {
        id = t.app; app = t.app; score = t.score; keystrokes = t.keystrokes
    }
}

struct DeviceEntry: Identifiable {
    let id: String
    let device: String
    let count: Int
    init(_ t: (device: String, count: Int)) { id = t.device; device = t.device; count = t.count }
}

struct DeviceErgScoreEntry: Identifiable {
    let id: String
    let device: String
    let score: Double
    let keystrokes: Int
    init(_ t: (device: String, score: Double, keystrokes: Int)) {
        id = t.device; device = t.device; score = t.score; keystrokes = t.keystrokes
    }
}

// Issue #5: Hourly distribution entry (for Chart)
// 時間帯別打鍵数チャート用エントリ
struct HourEntry: Identifiable {
    let id: Int
    let hour: Int
    let count: Int
    var hourLabel: String { String(format: "%02d:00", hour) }
    var isWorkHour: Bool { hour >= 9 && hour < 18 }
    init(hour: Int, count: Int) { id = hour; self.hour = hour; self.count = count }
}

// Issue #5: Monthly total entry
// 月別打鍵数合計エントリ
struct MonthlyTotalEntry: Identifiable {
    let id: String
    let month: String
    let total: Int
    init(_ t: (month: String, total: Int)) { id = t.month; month = t.month; total = t.total }
}

// MARK: - Phase 3 data types

/// One data point in the Learning Curve chart: a rate value for a given date and metric series.
/// 学習曲線チャートの1点：指定日・指標系列の比率値。
struct DailyErgonomicEntry: Identifiable {
    let id = UUID()
    let date: String
    let series: String   // "Same-finger" | "Alternation" | "High-strain"
    let rate: Double
}

/// One row in the Weekly Delta table: a metric compared across two consecutive 7-day windows.
/// 週次デルタ表の1行：連続する2つの7日間ウィンドウで比較した指標。
struct WeeklyDeltaRow: Identifiable {
    let id = UUID()
    let metric: String
    let thisWeek: Double
    let lastWeek: Double
    let lowerIsBetter: Bool
    var delta: Double { thisWeek - lastWeek }
}

// MARK: - SectionHeader

/// Section title with an optional hover-triggered help popover.
/// セクションタイトル + ホバーで表示されるヘルプポップオーバー（任意）。
private struct SectionHeader: View {
    let title: String
    let helpText: String
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(showHelp ? .primary : .secondary)
                .onHover { showHelp = $0 }
                .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                    Text(helpText)
                        .font(.callout)
                        .padding(10)
                        .frame(width: 280)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
    }
}

// MARK: - ChartTab

enum ChartTab: String, CaseIterable, Identifiable {
    case overview    = "Overview"
    case heatmap     = "Heatmap"
    case ergonomics  = "Ergonomics"
    case shortcuts   = "Shortcuts"
    case apps        = "Apps"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview:   return "info.circle"
        case .heatmap:    return "square.grid.3x3"
        case .ergonomics: return "figure.walk"
        case .shortcuts:  return "command"
        case .apps:       return "app.badge"
        }
    }
}

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel

    @AppStorage("selectedChartTab") private var selectedTab: ChartTab = .overview

    var body: some View {
        TabView(selection: $selectedTab) {
            overviewTab
                .tabItem { Label(ChartTab.overview.rawValue, systemImage: ChartTab.overview.icon) }
                .tag(ChartTab.overview)

            heatmapTab
                .tabItem { Label(ChartTab.heatmap.rawValue, systemImage: ChartTab.heatmap.icon) }
                .tag(ChartTab.heatmap)

            ergonomicsTab
                .tabItem { Label(ChartTab.ergonomics.rawValue, systemImage: ChartTab.ergonomics.icon) }
                .tag(ChartTab.ergonomics)

            shortcutsTab
                .tabItem { Label(ChartTab.shortcuts.rawValue, systemImage: ChartTab.shortcuts.icon) }
                .tag(ChartTab.shortcuts)

            appsTab
                .tabItem { Label(ChartTab.apps.rawValue, systemImage: ChartTab.apps.icon) }
                .tag(ChartTab.apps)
        }
        .padding(.top, 8)
        .frame(minWidth: 680, minHeight: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tabs

    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.intelligenceSection, helpText: L10n.shared.helpIntelligence) { intelligenceGroup }
                chartSection("Top 20 Keys — All Time") { topKeysChart }
                chartSection("Daily Totals") { dailyTotalsChart }
                chartSection("Activity Calendar", helpText: L10n.shared.helpActivityCalendar) { activityCalendarChart }
                chartSection("Hourly Distribution", helpText: L10n.shared.helpHourlyDistribution) { hourlyDistributionChart }
                chartSection("Monthly Totals") { monthlyTotalsChart }
                chartSection("Top 10 Keys per Day") { perDayChart }
            }
            .padding(24)
        }
    }

    private var heatmapTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Keyboard Heatmap") { KeyboardHeatmapView(counts: model.keyCounts) }
                chartSection("Key Categories") { categoryChart }
            }
            .padding(24)
        }
    }

    private var ergonomicsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Top 20 Bigrams", helpText: L10n.shared.helpBigrams) { bigramChart }
                chartSection("Layout Comparison", helpText: L10n.shared.helpLayoutComparison) { layoutComparisonSection }
                chartSection("Ergonomic Learning Curve", helpText: L10n.shared.helpLearningCurve) { learningCurveChart }
                chartSection("Weekly Report") { weeklyDeltaSection }
            }
            .padding(24)
        }
    }

    private var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("⌘ Keyboard Shortcuts") { shortcutsChart }
                chartSection("All Keyboard Combos") { allCombosChart }
            }
            .padding(24)
        }
    }

    private var appsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.appsAllTime, helpText: L10n.shared.helpApps) { topAppsChart }
                chartSection(L10n.shared.appsToday) { todayTopAppsChart }
                if !model.appErgScores.isEmpty {
                    chartSection(L10n.shared.appErgScoreSection, helpText: L10n.shared.helpAppErgScore) {
                        appErgScoreTable
                    }
                }
                chartSection(L10n.shared.devicesAllTime, helpText: L10n.shared.helpDevices) { topDevicesChart }
                chartSection(L10n.shared.devicesToday) { todayTopDevicesChart }
                if !model.deviceErgScores.isEmpty {
                    chartSection(L10n.shared.deviceErgScoreSection, helpText: L10n.shared.helpDeviceErgScore) {
                        deviceErgScoreTable
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Per-app ergonomic score table

    private var appErgScoreTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text(L10n.shared.appErgScoreAppHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.shared.appErgScoreKeysHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                Text(L10n.shared.appErgScoreScoreHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            ForEach(model.appErgScores) { entry in
                HStack {
                    Text(entry.app)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(entry.keystrokes.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 4) {
                        // Score bar (fills proportionally from 0–100)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor(entry.score).opacity(0.25))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(scoreColor(entry.score))
                                        .frame(width: geo.size.width * entry.score / 100)
                                }
                        }
                        .frame(width: 44, height: 8)
                        Text(String(format: "%.0f", entry.score))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(scoreColor(entry.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
    }

    private var deviceErgScoreTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.shared.deviceErgScoreDeviceHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.shared.deviceErgScoreKeysHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                Text(L10n.shared.deviceErgScoreScoreHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            ForEach(model.deviceErgScores) { entry in
                HStack {
                    Text(entry.device)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(entry.keystrokes.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 4) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor(entry.score).opacity(0.25))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(scoreColor(entry.score))
                                        .frame(width: geo.size.width * entry.score / 100)
                                }
                        }
                        .frame(width: 44, height: 8)
                        Text(String(format: "%.0f", entry.score))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(scoreColor(entry.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func chartSection<C: View>(_ title: String, helpText: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let helpText {
                SectionHeader(title: title, helpText: helpText)
            } else {
                Text(title).font(.headline)
            }
            content()
        }
    }

    // MARK: - Phase 4: Intelligence Insights

    @ViewBuilder
    private var intelligenceGroup: some View {
        HStack(spacing: 40) {
            intelligenceCard(
                title: L10n.shared.inferredStyle,
                value: L10n.shared.typingStyleLabel(KeyCountStore.shared.currentTypingStyle),
                icon: styleIcon(KeyCountStore.shared.currentTypingStyle),
                color: .blue
            )

            intelligenceCard(
                title: L10n.shared.fatigueRisk,
                value: L10n.shared.fatigueLevelLabel(KeyCountStore.shared.currentFatigueLevel),
                icon: fatigueIcon(KeyCountStore.shared.currentFatigueLevel),
                color: fatigueColor(KeyCountStore.shared.currentFatigueLevel)
            )
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func intelligenceCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func styleIcon(_ style: TypingStyle) -> String {
        switch style {
        case .prose:   return "doc.text"
        case .code:    return "terminal"
        case .chat:    return "message"
        case .unknown: return "questionmark.circle"
        }
    }

    private func fatigueIcon(_ level: FatigueLevel) -> String {
        switch level {
        case .low:      return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high:     return "exclamationmark.octagon.fill"
        }
    }

    private func fatigueColor(_ level: FatigueLevel) -> Color {
        switch level {
        case .low:      return .green
        case .moderate: return .orange
        case .high:     return .red
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

    // MARK: - Apps Charts

    @ViewBuilder
    private var topAppsChart: some View {
        if model.topApps.isEmpty {
            emptyState
        } else {
            let appOrder = model.topApps.map(\.app)
            Chart(model.topApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: appOrder.reversed())
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.topApps.count * 28 + 24))
        }
    }

    @ViewBuilder
    private var todayTopAppsChart: some View {
        if model.todayTopApps.isEmpty {
            emptyState
        } else {
            let appOrder = model.todayTopApps.map(\.app)
            Chart(model.todayTopApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: appOrder.reversed())
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.todayTopApps.count * 28 + 24))
        }
    }

    @ViewBuilder
    private var topDevicesChart: some View {
        if model.topDevices.isEmpty {
            emptyState
        } else {
            let deviceOrder = model.topDevices.map(\.device)
            Chart(model.topDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: deviceOrder.reversed())
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.topDevices.count * 28 + 24))
        }
    }

    @ViewBuilder
    private var todayTopDevicesChart: some View {
        if model.todayTopDevices.isEmpty {
            emptyState
        } else {
            let deviceOrder = model.todayTopDevices.map(\.device)
            Chart(model.todayTopDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: deviceOrder.reversed())
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.todayTopDevices.count * 28 + 24))
        }
    }

    // MARK: - Chart 2: Top 20 Bigrams (horizontal bar + ergonomic summary)

    @ViewBuilder
    private var bigramChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.topBigrams.isEmpty {
                emptyState
            } else {
                let pairOrder = model.topBigrams.map(\.pair)
                Chart(model.topBigrams) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Bigram", item.pair)
                    )
                    .foregroundStyle(Color.teal.opacity(0.8))
                    .cornerRadius(3)
                }
                .chartYScale(domain: pairOrder.reversed())
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topBigrams.count * 26 + 24))
            }

            // Ergonomic metrics summary (Phase 0 data — previously computed but not shown)
            HStack(spacing: 24) {
                ergonomicMetricPair(
                    label: "Same-finger rate",
                    allTime: model.sameFingerRate,
                    today: model.todaySameFingerRate
                )
                ergonomicMetricPair(
                    label: "Hand alternation rate",
                    allTime: model.handAlternationRate,
                    today: model.todayHandAltRate
                )
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func ergonomicMetricPair(label: String, allTime: Double?, today: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let v = allTime {
                    Text("All-time: \(Int(v * 100))%").font(.caption.monospacedDigit())
                }
                if let v = today {
                    Text("Today: \(Int(v * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if allTime == nil && today == nil {
                    Text("—").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Chart 3: Daily Totals (line chart)

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

    // MARK: - Chart 6: All Keyboard Combos (horizontal bar, modifier-color-coded)

    @ViewBuilder
    private var allCombosChart: some View {
        if model.allCombos.isEmpty {
            emptyState
        } else {
            let keyOrder = model.allCombos.map(\.key)
            VStack(alignment: .leading, spacing: 6) {
                Chart(model.allCombos) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Combo", item.key)
                    )
                    .foregroundStyle(comboColor(item.key))
                    .cornerRadius(3)
                    .annotation(position: .trailing, spacing: 4) {
                        Text(item.count.formatted())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: keyOrder.reversed())
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.allCombos.count * 26 + 24))

                // 凡例
                HStack(spacing: 14) {
                    ForEach([("⌘", Color.teal), ("⌃", Color.orange), ("⌥", Color.purple), ("⇧", Color.green), ("Multi", Color.pink)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func comboColor(_ key: String) -> Color {
        let modifiers = ["⌘", "⌃", "⌥", "⇧"]
        let found = modifiers.filter { key.hasPrefix($0) || key.contains($0) }
        if found.count > 1 { return .pink }
        switch found.first {
        case "⌘": return .teal
        case "⌃": return .orange
        case "⌥": return .purple
        case "⇧": return .green
        default:   return .gray
        }
    }

    // MARK: - Phase 2: Layout Comparison (Before/After)

    @ViewBuilder
    private var layoutComparisonSection: some View {
        if let cmp = model.layoutComparison {
            VStack(alignment: .leading, spacing: 12) {
                // Recommended swaps header
                // 推奨スワップのヘッダー
                let swapLabels = cmp.recommendedSwaps
                    .map { "\($0.from) ↔ \($0.to)" }
                    .joined(separator: ", ")
                Text("Recommended swaps: \(swapLabels)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Comparison Grid table
                // 比較グリッドテーブル
                Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                    // Header row
                    GridRow {
                        Text("Metric")
                            .font(.caption).bold().foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text("Current")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Proposed")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Change")
                            .font(.caption).bold().foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider().gridCellUnsizedAxes(.horizontal)

                    // Ergonomic score (higher is better)
                    comparisonRow(
                        metric: "Ergonomic score",
                        current:  String(format: "%.1f", cmp.current.ergonomicScore),
                        proposed: String(format: "%.1f", cmp.proposed.ergonomicScore),
                        delta: cmp.ergonomicScoreDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.1f", d) }
                    )

                    // Same-finger rate (lower is better)
                    comparisonRow(
                        metric: "Same-finger rate",
                        current:  pct(cmp.current.sameFingerRate),
                        proposed: pct(cmp.proposed.sameFingerRate),
                        delta: cmp.sameFingerRateDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // Hand alternation rate (higher is better)
                    comparisonRow(
                        metric: "Hand alternation",
                        current:  pct(cmp.current.handAlternationRate),
                        proposed: pct(cmp.proposed.handAlternationRate),
                        delta: cmp.handAlternationDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // High-strain rate (lower is better)
                    comparisonRow(
                        metric: "High-strain rate",
                        current:  pct(cmp.current.highStrainRate),
                        proposed: pct(cmp.proposed.highStrainRate),
                        delta: cmp.highStrainRateDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // Thumb imbalance (lower is better)
                    comparisonRow(
                        metric: "Thumb imbalance",
                        current:  String(format: "%.2f", cmp.current.thumbImbalanceRatio),
                        proposed: String(format: "%.2f", cmp.proposed.thumbImbalanceRatio),
                        delta: cmp.thumbImbalanceDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.2f", d) }
                    )

                    // Finger travel (lower is better)
                    comparisonRow(
                        metric: "Finger travel",
                        current:  String(format: "%.0f", cmp.current.estimatedTravelDistance),
                        proposed: String(format: "%.0f", cmp.proposed.estimatedTravelDistance),
                        delta: cmp.travelDistanceDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.0f", d) }
                    )
                }
                .padding(.vertical, 8)
            }
        } else {
            Text("Need more typing data to compute layout comparison")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        }
    }

    /// Renders one row of the comparison table with colour-coded change column.
    /// 比較テーブルの1行を色付きの変化列と共にレンダリングする。
    @ViewBuilder
    private func comparisonRow(
        metric: String,
        current: String,
        proposed: String,
        delta: Double,
        positiveIsBetter: Bool,
        format: (Double) -> String
    ) -> some View {
        let threshold = 0.001
        let isImprovement = positiveIsBetter ? delta > threshold  : delta < -threshold
        let isRegression  = positiveIsBetter ? delta < -threshold : delta > threshold
        let color: Color  = isImprovement ? .green : (isRegression ? .red : .secondary)
        let arrow: String = delta > threshold ? "↑" : (delta < -threshold ? "↓" : "→")

        GridRow {
            Text(metric)
                .font(.callout)
                .gridColumnAlignment(.leading)
            Text(current)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(proposed)
                .font(.callout.monospacedDigit())
            Text("\(arrow) \(format(delta))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.vertical, 5)
    }

    /// Formats a rate as a percentage string (e.g. 0.083 → "8.3%").
    /// 比率をパーセント文字列に変換する。
    private func pct(_ rate: Double) -> String { String(format: "%.1f%%", rate * 100) }

    /// Formats a rate delta as percentage points (e.g. 0.042 → "+4.2pp").
    /// 比率差をパーセントポイント表記に変換する。
    private func pp(_ delta: Double) -> String { String(format: "%+.1fpp", delta * 100) }

    // MARK: - Phase 3: Learning Curve (daily ergonomic trend)

    @ViewBuilder
    private var learningCurveChart: some View {
        if model.dailyErgonomics.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(model.dailyErgonomics) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Rate", item.rate)
                    )
                    .foregroundStyle(by: .value("Metric", item.series))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Rate", item.rate)
                    )
                    .foregroundStyle(by: .value("Metric", item.series))
                }
                .chartForegroundStyleScale([
                    "Same-finger": Color.orange,
                    "Alternation": Color.teal,
                    "High-strain": Color.red
                ])
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    ForEach([("Same-finger", Color.orange), ("Alternation", Color.teal), ("High-strain", Color.red)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Phase 3: Weekly Delta Report

    @ViewBuilder
    private var weeklyDeltaSection: some View {
        if model.weeklyDeltas.isEmpty {
            Text("Need at least two weeks of data")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                    GridRow {
                        Text("Metric")
                            .font(.caption).bold().foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text("This week")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Last week")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Δ")
                            .font(.caption).bold().foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider()
                        .gridCellUnsizedAxes(.horizontal)

                    ForEach(model.weeklyDeltas) { row in
                        GridRow {
                            Text(row.metric)
                                .font(.callout)
                                .gridColumnAlignment(.leading)
                            Text(weeklyFormat(row.thisWeek, metric: row.metric))
                                .font(.callout.monospacedDigit())
                            Text(weeklyFormat(row.lastWeek, metric: row.metric))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                            deltaLabel(row)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func weeklyFormat(_ value: Double, metric: String) -> String {
        if metric == "Keystrokes" {
            return Int(value).formatted()
        } else {
            return "\(Int(value * 100))%"
        }
    }

    @ViewBuilder
    private func deltaLabel(_ row: WeeklyDeltaRow) -> some View {
        let threshold = row.metric == "Keystrokes" ? 0.01 : 0.005
        let isImprovement = row.lowerIsBetter ? row.delta < -threshold : row.delta > threshold
        let isRegression  = row.lowerIsBetter ? row.delta > threshold  : row.delta < -threshold
        let color: Color  = isImprovement ? .green : (isRegression ? .red : .secondary)

        let absStr: String = {
            if row.metric == "Keystrokes" {
                return abs(Int(row.delta)).formatted()
            } else {
                return "\(Int(abs(row.delta) * 100))pp"
            }
        }()
        let arrow = row.delta > threshold ? "↑" : (row.delta < -threshold ? "↓" : "→")

        Text("\(arrow) \(absStr)")
            .font(.callout.monospacedDigit())
            .foregroundStyle(color)
    }

    // MARK: - Issue #5: Activity Calendar (heatmap)

    /// Calendar heatmap showing daily keystroke counts for the past 365 days.
    /// 過去365日の日別打鍵数をカレンダーヒートマップで表示する。
    @ViewBuilder
    private var activityCalendarChart: some View {
        if model.dailyTotals.isEmpty {
            emptyState
        } else {
            ActivityCalendarView(dailyTotals: model.dailyTotals)
        }
    }

    // MARK: - Issue #5: Hourly Distribution (bar chart)

    /// 24-bar chart showing aggregate keystroke count by hour of day.
    /// 時刻（0〜23時）別の累積打鍵数棒グラフ。
    @ViewBuilder
    private var hourlyDistributionChart: some View {
        let dist = model.hourlyDistribution
        if dist.isEmpty || dist.allSatisfy({ $0 == 0 }) {
            emptyState
        } else {
            let entries = dist.enumerated().map { HourEntry(hour: $0.offset, count: $0.element) }
            Chart(entries) { item in
                BarMark(
                    x: .value("Hour", item.hourLabel),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(item.isWorkHour ? Color.blue.opacity(0.75) : Color.blue.opacity(0.35))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23].map { String(format: "%02d:00", $0) }) { value in
                    AxisValueLabel { Text(value.as(String.self) ?? "") }
                    AxisGridLine()
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - Issue #5: Monthly Totals (bar chart)

    /// Bar chart of total keystrokes per calendar month (last 12 months).
    /// 月別打鍵数合計の棒グラフ（直近12ヶ月）。
    @ViewBuilder
    private var monthlyTotalsChart: some View {
        let entries = Array(model.monthlyTotals.suffix(12))
        if entries.isEmpty {
            emptyState
        } else {
            Chart(entries) { item in
                BarMark(
                    x: .value("Month", item.month),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.teal.opacity(0.75))
                .cornerRadius(4)
                .annotation(position: .top, spacing: 3) {
                    Text(item.total.formatted(.number.notation(.compactName)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            // "yyyy-MM" → show "yy/MM" for compactness
                            // 表示例: "2024-03" → "24/03"
                            let parts = s.split(separator: "-")
                            let label = parts.count == 2
                                ? "\(String(parts[0]).suffix(2))/\(parts[1])"
                                : s
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("(no data yet)")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

// MARK: - ActivityCalendarView (Issue #5)

/// Contribution calendar heatmap showing daily keystroke counts.
/// Displays the past 365 days as a 53-column × 7-row grid, coloured by keystroke intensity.
///
/// カレンダーヒートマップ：日別打鍵数を色の濃淡で表現する。
/// 過去365日を53列 × 7行グリッドで表示し、打鍵数の強度に応じて色付けする。
struct ActivityCalendarView: View {
    let dailyTotals: [DailyTotalEntry]

    // Calendar cell size and spacing
    // カレンダーセルのサイズとスペーシング
    private let cellSize: CGFloat = 12
    private let spacing: CGFloat  = 2

    // Build a lookup from date string → total count
    // 日付文字列 → 合計打鍵数のルックアップを構築する
    private var countMap: [String: Int] {
        Dictionary(uniqueKeysWithValues: dailyTotals.map { ($0.date, $0.total) })
    }

    // The maximum daily count (used to normalise intensity levels)
    // 強度正規化に使用する1日の最大打鍵数
    private var maxCount: Int {
        dailyTotals.map(\.total).max() ?? 1
    }

    // Build an ordered list of (dateString, count) for the past 365 days,
    // padded at the start so the first cell falls on a Sunday.
    // 過去365日の (日付文字列, 打鍵数) リストを構築し、先頭を日曜に揃える。
    private var calendarDays: [(date: String, count: Int)] {
        let cal     = Calendar.current
        let fmt     = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today   = Date()

        // 365 actual days ending today
        // 今日を含む過去365日
        let actualDays: [Date] = (0..<365).compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        let firstDay   = actualDays.first ?? today
        let weekday    = cal.component(.weekday, from: firstDay)  // 1=Sun
        let leadingPad = weekday - 1                              // 0-based offset to Sunday

        var days: [(date: String, count: Int)] = []
        // Pad leading empty slots so the grid starts on Sunday
        // グリッドを日曜始まりにするための空スロットを先頭に追加
        for _ in 0..<leadingPad {
            days.append((date: "", count: 0))
        }
        let map = countMap
        for d in actualDays {
            let key = fmt.string(from: d)
            days.append((date: key, count: map[key] ?? 0))
        }
        return days
    }

    var body: some View {
        let days   = calendarDays
        let max    = maxCount
        let cols   = Int(ceil(Double(days.count) / 7.0))

        VStack(alignment: .leading, spacing: 6) {
            // Day-of-week labels (Sun … Sat)
            // 曜日ラベル（Sun〜Sat）
            HStack(spacing: 0) {
                // Indent to match grid columns offset — no leading label column here
                // グリッドに合わせた先頭スペース
                Spacer().frame(width: 0)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        // DOW header column (Sun → Sat labels on left side)
                        // 曜日ヘッダー列（左側）
                        VStack(alignment: .trailing, spacing: spacing) {
                            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { label in
                                Text(label)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }

                        // Week columns
                        // 週ごとの列
                        ForEach(0..<cols, id: \.self) { col in
                            VStack(spacing: spacing) {
                                ForEach(0..<7, id: \.self) { row in
                                    let idx = col * 7 + row
                                    if idx < days.count && !days[idx].date.isEmpty {
                                        let day = days[idx]
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(intensityColor(count: day.count, max: max))
                                            .frame(width: cellSize, height: cellSize)
                                            .help("\(day.date): \(day.count.formatted()) keystrokes")
                                    } else {
                                        // Empty padding slot or out-of-range
                                        // 空スロット
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.clear)
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                            .id(col)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .onAppear {
                    // Scroll to the rightmost (most recent) week on load
                    // 表示時に最新週（右端）へスクロール
                    proxy.scrollTo(cols - 1, anchor: .trailing)
                }
            }

            // Intensity legend
            // 強度凡例
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    let frac = level == 0 ? 0.0 : Double(level) / 4.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(fraction: frac))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// Returns a color for a given count relative to the maximum.
    /// 最大値を基準に打鍵数に対応する色を返す。
    private func intensityColor(count: Int, max: Int) -> Color {
        let fraction = max > 0 ? Double(count) / Double(max) : 0.0
        return intensityColor(fraction: fraction)
    }

    /// Maps a normalized fraction [0,1] to a green-tinted intensity color.
    /// 正規化された割合 [0,1] を緑系の強度色にマッピングする。
    private func intensityColor(fraction: Double) -> Color {
        if fraction == 0 { return Color(NSColor.controlBackgroundColor).opacity(0.6) }
        // 4-level green scale: light → dark
        // 4段階の緑スケール：薄い → 濃い
        switch fraction {
        case 0..<0.25: return Color.green.opacity(0.25)
        case 0.25..<0.50: return Color.green.opacity(0.50)
        case 0.50..<0.75: return Color.green.opacity(0.75)
        default:          return Color.green.opacity(1.00)
        }
    }
}
