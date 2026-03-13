import AppKit
import SwiftUI
import KeyLensCore

// MARK: - ChartDataModel

/// チャート用データを保持・更新する ObservableObject
final class ChartDataModel: ObservableObject {
    @Published var topKeys:              [TopKeyEntry]          = []
    @Published var dailyTotals:          [DailyTotalEntry]      = []
    @Published var categories:           [CategoryEntry]        = []
    @Published var perDayKeys:           [DailyKeyEntry]        = []
    @Published var shortcuts:            [ShortcutEntry]        = []
    @Published var allCombos:            [ShortcutEntry]        = []
    @Published var keyCounts:            [String: Int]          = [:]
    @Published var topBigrams:           [BigramEntry]          = []
    @Published var sameFingerRate:       Double?                = nil
    @Published var todaySameFingerRate:  Double?                = nil
    @Published var handAlternationRate:  Double?                = nil
    @Published var todayHandAltRate:     Double?                = nil
    // Phase 3
    @Published var dailyErgonomics:      [DailyErgonomicEntry]  = []
    @Published var weeklyDeltas:         [WeeklyDeltaRow]       = []
    // Phase 2: Before/After layout comparison (Issue #3)
    @Published var layoutComparison:          LayoutComparison? = nil
    @Published var isLayoutComparisonLoading: Bool              = false
    // Issue #5: Activity Trends
    @Published var hourlyDistribution:   [Int]                  = []
    @Published var monthlyTotals:        [MonthlyTotalEntry]    = []
    // Per-application counts
    @Published var topApps:              [AppEntry]             = []
    @Published var todayTopApps:         [AppEntry]             = []
    // Per-application ergonomic scores
    @Published var appErgScores:         [AppErgScoreEntry]     = []
    // Per-device counts
    @Published var topDevices:           [DeviceEntry]          = []
    @Published var todayTopDevices:      [DeviceEntry]          = []
    // Per-device ergonomic scores
    @Published var deviceErgScores:      [DeviceErgScoreEntry]  = []
    // Issue #59 Phase 2: daily WPM time-series
    // 日別 WPM 時系列（タイピング速度チャート用）
    @Published var dailyWPM:             [DailyWPMEntry]        = []
    // Issue #65: daily backspace rate time-series
    // 日別 BS 率時系列（タイピング精度チャート用）
    @Published var dailyAccuracy:        [DailyAccuracyEntry]   = []
    // Live IKI ring buffer — refreshed every 0.5s by a timer in ChartsWindowController.
    // リアルタイムIKIリングバッファ（ChartsWindowControllerのタイマーで0.5秒ごとに更新）。
    @Published var recentIKIEntries:     [RecentIKIEntry]       = []

    func reload() {
        let store            = KeyCountStore.shared
        topKeys              = store.topKeys(limit: 20).map(TopKeyEntry.init)
        let rawDailyTotals   = store.dailyTotals()
        dailyTotals          = rawDailyTotals.map(DailyTotalEntry.init)
        categories           = store.countsByType().map(CategoryEntry.init)
        perDayKeys           = store.topKeysPerDay(limit: 10).map(DailyKeyEntry.init)
        shortcuts            = store.topModifiedKeys(prefix: "⌘", limit: 20).map(ShortcutEntry.init)
        allCombos            = store.topModifiedKeys(prefix: "", limit: 30).map(ShortcutEntry.init)
        keyCounts            = Dictionary(uniqueKeysWithValues: store.allEntries().map { ($0.key, $0.total) })
        topBigrams           = store.topBigrams(limit: 20).map(BigramEntry.init)
        sameFingerRate       = store.sameFingerRate
        todaySameFingerRate  = store.todaySameFingerRate
        handAlternationRate  = store.handAlternationRate
        todayHandAltRate     = store.todayHandAlternationRate

        // Phase 3: Learning Curve
        let ergRates = store.dailyErgonomicRates()
        dailyErgonomics = ergRates.flatMap { row -> [DailyErgonomicEntry] in
            [
                DailyErgonomicEntry(date: row.date, series: "Same-finger", rate: row.sameFingerRate),
                DailyErgonomicEntry(date: row.date, series: "Alternation",  rate: row.handAltRate),
                DailyErgonomicEntry(date: row.date, series: "High-strain",  rate: row.highStrainRate),
            ]
        }

        // Phase 3: Weekly Delta (this 7 days vs. previous 7 days)
        weeklyDeltas = Self.computeWeeklyDeltas(ergRates: ergRates, rawDailyTotals: rawDailyTotals)

            // Phase 2: Before/After layout comparison — run FullErgonomicOptimizer on a background
        // thread so the main thread (and Charts window) is never blocked.
        // FullErgonomicOptimizer はバックグラウンドスレッドで実行し、メインスレッドをブロックしない。
        layoutComparison = nil
        isLayoutComparisonLoading = true
        let bigramSnapshot = store.allBigramCounts
        let keySnapshot    = store.allKeyCounts
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = LayoutComparison.make(bigramCounts: bigramSnapshot, keyCounts: keySnapshot)
            DispatchQueue.main.async {
                self?.layoutComparison = result
                self?.isLayoutComparisonLoading = false
            }
        }

        // Issue #5: Activity Trends
        hourlyDistribution = store.hourlyDistribution()
        monthlyTotals      = store.monthlyTotals().map(MonthlyTotalEntry.init)
        // Per-application counts
        topApps      = store.topApps(limit: 20).map(AppEntry.init)
        todayTopApps = store.todayTopApps(limit: 10).map(AppEntry.init)
        appErgScores = store.appErgonomicScores(minKeystrokes: 100).map(AppErgScoreEntry.init)
        // Per-device counts
        topDevices      = store.topDevices(limit: 20).map(DeviceEntry.init)
        todayTopDevices = store.todayTopDevices(limit: 10).map(DeviceEntry.init)
        deviceErgScores = store.deviceErgonomicScores(minKeystrokes: 100).map(DeviceErgScoreEntry.init)
        // Issue #59 Phase 2: daily WPM
        dailyWPM = store.dailyWPM().map(DailyWPMEntry.init)
        // Issue #65: daily backspace rate
        dailyAccuracy = store.dailyBackspaceRates().map(DailyAccuracyEntry.init)
    }

    /// Lightweight refresh — reads only the live IKI ring buffer. Called by the 0.5s timer.
    func refreshLiveData() {
        let raw = KeyCountStore.shared.latestIKIs()
        recentIKIEntries = raw.enumerated().map { i, item in
            RecentIKIEntry(id: i, key: item.key, iki: item.iki)
        }
    }

    // Compare the most recent 7 days against the 7 days before that.
    // 直近7日 vs その前7日の比較。
    private static func computeWeeklyDeltas(
        ergRates: [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)],
        rawDailyTotals: [(date: String, total: Int)]
    ) -> [WeeklyDeltaRow] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()

        func dateStr(_ daysAgo: Int) -> String? {
            Calendar.current.date(byAdding: .day, value: -daysAgo, to: today).map { fmt.string(from: $0) }
        }

        let thisWeekDates = Set((0..<7).compactMap  { dateStr($0) })
        let lastWeekDates = Set((7..<14).compactMap { dateStr($0) })

        // Keystroke totals per week
        let totalMap = Dictionary(uniqueKeysWithValues: rawDailyTotals.map { ($0.date, $0.total) })
        let thisWeekKeys = Double(thisWeekDates.compactMap { totalMap[$0] }.reduce(0, +))
        let lastWeekKeys = Double(lastWeekDates.compactMap { totalMap[$0] }.reduce(0, +))

        // Average ergonomic rate over a set of dates
        func avg(_ dates: Set<String>, _ selector: (Double, Double, Double) -> Double) -> Double? {
            let vals = ergRates
                .filter { dates.contains($0.date) }
                .map    { selector($0.sameFingerRate, $0.handAltRate, $0.highStrainRate) }
            return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
        }

        var rows: [WeeklyDeltaRow] = []

        // Always include keystrokes (even if last week is 0)
        if thisWeekKeys > 0 || lastWeekKeys > 0 {
            rows.append(WeeklyDeltaRow(metric: "Keystrokes",      thisWeek: thisWeekKeys, lastWeek: lastWeekKeys, lowerIsBetter: false))
        }
        if let tw = avg(thisWeekDates, { sf, _, _ in sf }), let lw = avg(lastWeekDates, { sf, _, _ in sf }) {
            rows.append(WeeklyDeltaRow(metric: "Same-finger rate", thisWeek: tw, lastWeek: lw, lowerIsBetter: true))
        }
        if let tw = avg(thisWeekDates, { _, ha, _ in ha }), let lw = avg(lastWeekDates, { _, ha, _ in ha }) {
            rows.append(WeeklyDeltaRow(metric: "Alternation rate", thisWeek: tw, lastWeek: lw, lowerIsBetter: false))
        }
        if let tw = avg(thisWeekDates, { _, _, hs in hs }), let lw = avg(lastWeekDates, { _, _, hs in hs }) {
            rows.append(WeeklyDeltaRow(metric: "High-strain rate", thisWeek: tw, lastWeek: lw, lowerIsBetter: true))
        }
        return rows
    }
}

// MARK: - ChartsWindowController

/// Swift Charts を NSHostingController で包んで表示するウィンドウ
final class ChartsWindowController: NSWindowController {
    static let shared = ChartsWindowController()
    private let model = ChartDataModel()
    private var liveTimer: Timer?

    private init() {
        let hostVC = NSHostingController(rootView: ChartsView(model: model))
        let window = NSWindow(contentViewController: hostVC)
        window.title = "KeyLens — Charts"
        window.setContentSize(NSSize(width: 700, height: 650))
        window.center()
        window.setFrameAutosaveName("ChartsWindow")
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        model.reload()
        if !(window?.isVisible ?? false) { window?.center() }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        startLiveTimer()
    }

    private func startLiveTimer() {
        guard liveTimer == nil else { return }
        liveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.model.refreshLiveData()
        }
    }
}
