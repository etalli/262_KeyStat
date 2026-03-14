import SwiftUI
import Charts
import KeyLensCore

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel
    @ObservedObject private var theme = ThemeStore.shared

    @AppStorage("selectedChartTab") private var selectedTab: ChartTab = .summary
    @AppStorage("frequentChartsSortDescending") private var sortDescending: Bool = true

    /// Title of the section whose clipboard copy just succeeded (cleared after 1.5 s).
    @State private var copiedSection: String? = nil
    /// Stores each chart section's SwiftUI global frame and the Charts NSWindow reference.
    @State private var snapperStore = SnapperStore()
    /// Timer that drives real-time refresh on the Live tab.
    @State private var liveTimer: Timer? = nil

    /// Fixed width keeps the live IKI snapshot compact when copying to the clipboard.
    /// 最新20打鍵グラフのコピーサイズを安定させるための固定幅。
    private let recentIKIChartWidth: CGFloat = 560
    /// Slightly taller plot area leaves room for top annotations without making the snapshot too tall.
    /// 上端注釈が切れないように、コピー全体を伸ばしすぎず最小限だけ高さを増やす。
    private let recentIKIPlotHeight: CGFloat = 200
    /// Extra Y-axis headroom prevents top annotations from being clipped at the 300ms ceiling.
    /// 300ms天井で上端注釈が切れないように、表示用のヘッドルームを少し確保する。
    private let recentIKIChartMaxDisplay: Double = 340

    var body: some View {
        TabView(selection: $selectedTab) {
            summaryTab
                .tabItem { Label(ChartTab.summary.rawValue, systemImage: ChartTab.summary.icon) }
                .tag(ChartTab.summary)

            liveTab
                .tabItem { Label(ChartTab.live.rawValue, systemImage: ChartTab.live.icon) }
                .tag(ChartTab.live)

            activityTab
                .tabItem { Label(ChartTab.activity.rawValue, systemImage: ChartTab.activity.icon) }
                .tag(ChartTab.activity)

            keyboardTab
                .tabItem { Label(ChartTab.keyboard.rawValue, systemImage: ChartTab.keyboard.icon) }
                .tag(ChartTab.keyboard)

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
        .overlay(alignment: .topLeading) {
            // Grabs the NSWindow reference and silences the beep on plain typing.
            WindowGrabber(store: snapperStore).frame(width: 1, height: 1).opacity(0)
            KeySilencer().frame(width: 1, height: 1).opacity(0)
        }
    }

    // MARK: - Tabs

    // Summary: high-level health check — intelligence, weekly report, 365-day calendar
    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.intelligenceSection, helpText: L10n.shared.helpIntelligence) { intelligenceGroup }
                chartSection("Weekly Report") { weeklyDeltaSection }
                chartSection("Activity Calendar", helpText: L10n.shared.helpActivityCalendar) { activityCalendarChart }
            }
            .padding(24)
        }
    }

    // Live: real-time IKI chart, refreshed every second while this tab is active.
    private var liveTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartSection(L10n.shared.chartTitleRecentIKI, helpText: L10n.shared.helpRecentIKI) { recentIKIChart }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
                .padding(.leading, 24)
                .padding(.bottom, 24)
                .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.refreshLiveData()
            liveTimer?.invalidate()
            liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                model.refreshLiveData()
            }
        }
        .onDisappear {
            liveTimer?.invalidate()
            liveTimer = nil
        }
    }

    // Activity: all time-series charts — volume, speed, accuracy, patterns
    private var activityTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Daily Totals") { dailyTotalsChart }
                chartSection(L10n.shared.chartTitleTypingSpeed, helpText: L10n.shared.helpTypingSpeed) { dailyWPMChart }
                chartSection(L10n.shared.chartTitleBackspaceRate, helpText: L10n.shared.helpBackspaceRate) { dailyAccuracyChart }
                chartSection("Hourly Distribution", helpText: L10n.shared.helpHourlyDistribution) { hourlyDistributionChart }
                chartSection("Monthly Totals") { monthlyTotalsChart }
            }
            .padding(24)
        }
    }

    // Keyboard: per-key frequency analysis + heatmap
    private var keyboardTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Keyboard Heatmap") { KeyboardHeatmapView(counts: model.keyCounts) }
                chartSection("Top 20 Keys — All Time", showSort: true) { topKeysChart }
                chartSection("Key Categories") { categoryChart }
                chartSection("Top 10 Keys per Day", showSort: true) { perDayChart }
            }
            .padding(24)
        }
    }

    // Ergonomics: layout health — bigrams, learning curve, layout comparison
    private var ergonomicsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Top 20 Bigrams", helpText: L10n.shared.helpBigrams, showSort: true) { bigramChart }
                chartSection("Ergonomic Learning Curve", helpText: L10n.shared.helpLearningCurve) { learningCurveChart }
                chartSection("Layout Comparison", helpText: L10n.shared.helpLayoutComparison) { layoutComparisonSection }
            }
            .padding(24)
        }
    }

    private var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("⌘ Keyboard Shortcuts", showSort: true) { shortcutsChart }
                chartSection("All Keyboard Combos", showSort: true) { allCombosChart }
            }
            .padding(24)
        }
    }

    private var appsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.appsAllTime, helpText: L10n.shared.helpApps, showSort: true) { topAppsChart }
                chartSection(L10n.shared.appsToday, showSort: true) { todayTopAppsChart }
                if !model.appErgScores.isEmpty {
                    chartSection(L10n.shared.appErgScoreSection, helpText: L10n.shared.helpAppErgScore) {
                        appErgScoreTable
                    }
                }
                chartSection(L10n.shared.devicesAllTime, helpText: L10n.shared.helpDevices, showSort: true) { topDevicesChart }
                chartSection(L10n.shared.devicesToday, showSort: true) { todayTopDevicesChart }
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
    private func chartSection<C: View>(_ title: String, helpText: String? = nil, showSort: Bool = false, @ViewBuilder content: () -> C) -> some View {
        let contentView = AnyView(content())
        let isCopied = copiedSection == title
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let helpText {
                    SectionHeader(title: title, helpText: helpText)
                } else {
                    Text(title).font(.headline)
                }

                Spacer()

                if showSort {
                    Picker("", selection: $sortDescending) {
                        Image(systemName: "arrow.down.square").tag(true)
                            .help("Descending (Most frequent first)")
                        Image(systemName: "arrow.up.square").tag(false)
                            .help("Ascending (Least frequent first)")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }

                // Copy to clipboard button
                Button {
                    snapshotToClipboard(title: title)
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "clipboard")
                        .font(.body)
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy chart as image")
                .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            ZStack(alignment: .topLeading) {
                // ChartSnapper sits behind contentView as a ZStack sibling so it has
                // a proper NSView superview and an always-current frame at click time.
                ChartSnapper(store: snapperStore, key: title).allowsHitTesting(false)
                contentView
            }
        }
    }

    /// Captures the composited on-screen pixels for `title`'s section and writes to NSPasteboard.
    /// Uses GeometryReader (SwiftUI global frame) + CGWindowListCreateImage (Metal-compatible).
    private func snapshotToClipboard(title: String) {
        guard let snapper = snapperStore.views[title],
              let superview = snapper.superview,
              let window = superview.window else { return }

        let scale = window.backingScaleFactor

        // Convert snapper.frame (superview coords) → window coords → screen coords.
        // snapper is a ZStack sibling of contentView, so its frame matches contentView exactly.
        let inWindow   = superview.convert(snapper.frame, to: nil)
        let onScreen   = window.convertToScreen(inWindow)
        let winOnScreen = window.frame

        guard let windowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return }

        // Map screen rect → CGImage pixel rect (top-left origin).
        let cropRect = CGRect(
            x:      (onScreen.minX - winOnScreen.minX) * scale,
            y:      (winOnScreen.maxY - onScreen.maxY) * scale,
            width:  onScreen.width  * scale,
            height: onScreen.height * scale
        )
        guard let cropped = windowImage.cropping(to: cropRect) else { return }

        let img = NSImage(cgImage: cropped,
                          size: NSSize(width: onScreen.width, height: onScreen.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
        copiedSection = title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedSection == title { copiedSection = nil }
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
                color: theme.accentColor
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
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder
            
            VStack(alignment: .leading, spacing: 6) {
                Chart(model.topKeys) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Key", item.key)
                    )
                    .foregroundStyle(KeyType.classify(item.key).color)
                    .cornerRadius(3)
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topKeys.count * 26 + 24))

                // カラーレジェンド
                let presentTypes = Set(model.topKeys.map { KeyType.classify($0.key) })
                HStack(spacing: 14) {
                    ForEach(KeyType.allCases, id: \.self) { type in
                        if presentTypes.contains(type) {
                            HStack(spacing: 4) {
                                Circle().fill(type.color).frame(width: 8, height: 8)
                                Text(type.label).font(.caption).foregroundStyle(.secondary)
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
            let domain = sortDescending ? Array(appOrder.reversed()) : appOrder
            
            Chart(model.topApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
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
            let domain = sortDescending ? Array(appOrder.reversed()) : appOrder
            
            Chart(model.todayTopApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
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
            let domain = sortDescending ? Array(deviceOrder.reversed()) : deviceOrder
            
            Chart(model.topDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
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
            let domain = sortDescending ? Array(deviceOrder.reversed()) : deviceOrder
            
            Chart(model.todayTopDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
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
                let domain = sortDescending ? Array(pairOrder.reversed()) : pairOrder
                
                Chart(model.topBigrams) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Bigram", item.pair)
                    )
                    .foregroundStyle(Color.teal.opacity(0.8))
                    .cornerRadius(3)
                }
                .chartYScale(domain: domain)
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
                    Text("All-time: \(Int(v * 100))%").font(.footnote.monospacedDigit())
                }
                if let v = today {
                    Text("Today: \(Int(v * 100))%").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
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
                    .foregroundStyle(theme.accentColor)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyTotals) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(theme.accentColor.opacity(0.12))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(theme.accentColor)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(theme.accentColor)
                .annotation(position: .top, spacing: 4) {
                    Text(item.total.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Chart: Typing Speed (WPM) — Issue #59 Phase 2

    @ViewBuilder
    private var dailyWPMChart: some View {
        if model.dailyWPM.isEmpty {
            emptyState
        } else if model.dailyWPM.count == 1 {
            Chart(model.dailyWPM) { item in
                BarMark(x: .value("Date", item.date), y: .value("WPM", item.wpm))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyWPM) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("WPM", item.wpm)
                )
                .foregroundStyle(.orange.opacity(0.12))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("WPM", item.wpm)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("WPM", item.wpm)
                )
                .foregroundStyle(.orange)
                .annotation(position: .top, spacing: 4) {
                    Text(String(format: "%.0f", item.wpm))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Chart: Backspace Rate (Accuracy) — Issue #65

    @ViewBuilder
    private var dailyAccuracyChart: some View {
        if model.dailyAccuracy.isEmpty {
            emptyState
        } else if model.dailyAccuracy.count == 1 {
            Chart(model.dailyAccuracy) { item in
                BarMark(x: .value("Date", item.date), y: .value("BS rate", item.rate))
                    .foregroundStyle(.red.opacity(0.7))
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyAccuracy) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("BS rate", item.rate)
                )
                .foregroundStyle(.red.opacity(0.10))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("BS rate", item.rate)
                )
                .foregroundStyle(.red.opacity(0.8))
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("BS rate", item.rate)
                )
                .foregroundStyle(.red.opacity(0.8))
                .annotation(position: .top, spacing: 4) {
                    Text(String(format: "%.1f%%", item.rate))
                        .font(.caption)
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
            let domain = sortDescending ? keyOrder : Array(keyOrder.reversed())

            Chart(model.perDayKeys) { item in
                BarMark(
                    x: .value("Key", item.key),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(by: .value("Date", item.date))
                .position(by: .value("Date", item.date))
                .cornerRadius(3)
            }
            .chartXScale(domain: domain)
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
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder
            
            Chart(model.shortcuts) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Shortcut", item.key)
                )
                .foregroundStyle(shortcutColor(item.key))
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
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
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder
            
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.allCombos.count * 26 + 24))

                // 凡例
                HStack(spacing: 14) {
                    ForEach([("⌘", Color.teal), ("⌃", Color.orange), ("⌥", Color.purple), ("⇧", Color.green), ("Multi", Color.pink)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption).foregroundStyle(.secondary)
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
        } else if model.isLayoutComparisonLoading {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Calculating layout comparison…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
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
                                    .font(.caption)
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
                            Text(label).font(.caption).foregroundStyle(.secondary)
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

    // MARK: - Recent IKI bar chart (live, updated every 0.5s)

    /// Set to true to show the actual key label above each IKI bar.
    /// WARNING: enabling this exposes keystrokes (including passwords) visually.
    /// Set to false (default) to hide key names for privacy.
    private let ikichartShowKeyLabels = false

    /// Bar chart of IKI (ms) for the last 20 keystrokes. Bars are color-coded by speed.
    /// 直近20打鍵のIKI棒グラフ。速度に応じて色分けする。
    @ViewBuilder
    private var recentIKIChart: some View {
        let entries = model.recentIKIEntries
        if entries.isEmpty {
            VStack(spacing: 6) {
                emptyState
                Text("Type with this window open to see live timing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: recentIKIChartWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(entries) { item in
                    let bar = BarMark(
                        x: .value("Key", item.id),
                        y: .value("IKI (ms)", item.chartIKI)
                    )
                    .foregroundStyle(item.isAnchor  ? Color.gray.opacity(0.4)   :
                                     item.isFast    ? Color.green.opacity(0.8)  :
                                     item.isSlow    ? Color.red.opacity(0.8)    :
                                                      Color.orange.opacity(0.75))
                    .cornerRadius(2)
                    if item.isSlow {
                        // Capped at 300ms — show actual value so it's distinct from a genuine 300ms bar.
                        bar.annotation(position: .top, spacing: 2) {
                            Text("\(Int(item.iki))ms")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Color.red)
                        }
                    } else if ikichartShowKeyLabels {
                        bar.annotation(position: .top, spacing: 2) {
                            Text(item.key)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        bar
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisGridLine() }
                }
                .chartYScale(domain: 0...recentIKIChartMaxDisplay)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 100, 200, 300]) { value in
                        AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0)ms") }
                        AxisGridLine()
                    }
                }
                .frame(height: recentIKIPlotHeight)
                HStack(spacing: 16) {
                    Label("Fast (<150ms)", systemImage: "circle.fill").foregroundStyle(.green)
                    Label("Medium",        systemImage: "circle.fill").foregroundStyle(.orange)
                    Label("Slow (>400ms)", systemImage: "circle.fill").foregroundStyle(.red)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(width: recentIKIChartWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
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
                        .font(.caption)
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
                                .font(.caption)
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

// MARK: - NSView snapshot helpers

/// Reference-type store for chart NSViews and the Charts NSWindow.
/// Being a class means mutations don't trigger SwiftUI re-renders.
final class SnapperStore {
    var views: [String: NSView] = [:]
    weak var window: NSWindow?
}

/// Tiny invisible NSViewRepresentable whose only job is to supply the NSWindow reference.
private struct WindowGrabber: NSViewRepresentable {
    let store: SnapperStore
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        if store.window == nil {
            DispatchQueue.main.async { store.window = nsView.window }
        }
    }
}

/// Accepts first responder so plain typing into the Charts window is silently swallowed
/// instead of triggering the system beep. Cmd/Ctrl shortcuts are passed through normally.
private final class KeySilencerView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        // Plain typing is captured by the CGEvent tap — just swallow it here.
    }
}

private struct KeySilencer: NSViewRepresentable {
    func makeNSView(context: Context) -> KeySilencerView { KeySilencerView() }
    func updateNSView(_ nsView: KeySilencerView, context: Context) {}
}

/// Transparent NSView subclass used as a position anchor inside each chart section.
private final class SnapperHost: NSView {}

/// Registers the chart section's NSView into SnapperStore for later screen capture.
private struct ChartSnapper: NSViewRepresentable {
    let store: SnapperStore
    let key: String
    func makeNSView(context: Context) -> SnapperHost { SnapperHost() }
    func updateNSView(_ nsView: SnapperHost, context: Context) {
        store.views[key] = nsView
    }
}

