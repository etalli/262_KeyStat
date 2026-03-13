import SwiftUI
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

// MARK: - Issue #65: Daily Backspace Rate entry (for Accuracy chart)
// 日別 BS 率エントリ（タイピング精度チャート用）
struct DailyAccuracyEntry: Identifiable {
    let id: String
    let date: String
    let rate: Double  // backspace rate (%), lower is better / 低いほど精度が高い
    init(_ t: (date: String, rate: Double)) { id = t.date; date = t.date; rate = t.rate }
}

// MARK: - Issue #59 Phase 2: Daily WPM entry (for Typing Speed chart)
// 日別推定 WPM エントリ（タイピング速度チャート用）
struct DailyWPMEntry: Identifiable {
    let id: String
    let date: String
    let wpm: Double
    init(_ t: (date: String, wpm: Double)) { id = t.date; date = t.date; wpm = t.wpm }
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

/// One entry in the live IKI bar chart: a recent keystroke with its inter-keystroke interval.
/// リアルタイムIKIバーチャートの1エントリ：直近打鍵のキー間隔（ms）。
struct RecentIKIEntry: Identifiable {
    let id: Int       // position index (0 = oldest)
    let key: String
    let iki: Double   // inter-keystroke interval in ms
    /// Color tier: fast <150ms, slow >400ms, medium otherwise.
    var isFast: Bool { iki < 150 }
    var isSlow: Bool { iki > 400 }
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
