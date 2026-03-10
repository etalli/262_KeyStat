import AppKit
import Foundation
import KeyLensCore
import UserNotifications

// MARK: - Data model

/// 永続化するデータ全体。startedAt でいつから記録を開始したかを保持する
private struct CountData: Codable {
    var startedAt: Date
    var counts: [String: Int]
    var dailyCounts: [String: [String: Int]]   // "yyyy-MM-dd" -> keyName -> count
    var lastInputTime: Date?
    var avgIntervalMs: Double                  // Welford 移動平均（単位: ms）
    var avgIntervalCount: Int                  // 平均の標本数
    var modifiedCounts: [String: Int]          // "⌘c", "⇧a" など修飾キー+キー組み合わせ
    var dailyMinIntervalMs: [String: Double]   // "yyyy-MM-dd" -> 当日の最小入力間隔（ms, 1000ms以内のみ）
    // Daily Welford average interval tracking (Issue #59 Phase 2) — for per-day WPM chart
    // 日別 Welford 平均間隔（日別 WPM チャート用）
    var dailyAvgIntervalMs:    [String: Double] // "yyyy-MM-dd" -> daily Welford avg interval (ms)
    var dailyAvgIntervalCount: [String: Int]    // "yyyy-MM-dd" -> daily Welford sample count
    // Same-finger bigram tracking (Issue #16)
    var sameFingerCount: Int                   // Cumulative same-finger consecutive pairs
    var totalBigramCount: Int                  // Cumulative consecutive pairs (denominator)
    var dailySameFingerCount: [String: Int]    // "yyyy-MM-dd" -> same-finger pairs that day
    var dailyTotalBigramCount: [String: Int]   // "yyyy-MM-dd" -> total pairs that day
    // Hand alternation tracking (Issue #17)
    var handAlternationCount: Int              // Cumulative hand-alternating pairs
    var dailyHandAlternationCount: [String: Int] // "yyyy-MM-dd" -> alternating pairs that day
    // Hourly keystroke counts (Issue #18) — key: "yyyy-MM-dd-HH", value: total keystrokes
    // Retention: entries older than 365 days are pruned on load.
    var hourlyCounts: [String: Int]
    // Bigram frequency table (Issue #12) — key: "a→s", value: cumulative count
    var bigramCounts: [String: Int]
    // Daily bigram frequency — "yyyy-MM-dd" -> pair -> count
    var dailyBigramCounts: [String: [String: Int]]
    // Bigram IKI accumulation (Issue #24) — for empirical calibration of same-finger penalty factors.
    // Stores the sum and sample count of inter-keystroke intervals (ms, ≤1000ms) per bigram pair.
    // avgIKI(bigram) = bigramIKISum[bigram] / bigramIKICount[bigram]
    // ビグラムごとの IKI を蓄積し、同指ペナルティ係数の実測校正に使用する。
    var bigramIKISum: [String: Double]   // "a→s" -> cumulative IKI sum (ms)
    var bigramIKICount: [String: Int]    // "a→s" -> number of IKI samples
    // Alternation reward accumulation (Issue #25) — running total of per-pair reward deltas.
    // Includes streak multiplier bonus when ≥3 consecutive alternating pairs are detected.
    // 交互打鍵報酬の累積スコア。ストリーク乗数ボーナスを含む。
    var alternationRewardScore: Double   // cumulative reward score
    // High-strain sequence tracking (Issue #28) — same finger + ≥1 row distance.
    // 高負荷シーケンス（同指 + 縦1行以上の移動）の追跡。
    var highStrainBigramCount: Int               // cumulative high-strain bigrams
    var dailyHighStrainBigramCount: [String: Int] // "yyyy-MM-dd" -> count
    var highStrainTrigramCount: Int               // cumulative high-strain trigrams
    var dailyHighStrainTrigramCount: [String: Int] // "yyyy-MM-dd" -> count
    // General trigram frequency table (Issue #12) — key: "a→s→d", value: cumulative count
    var trigramCounts: [String: Int]
    // Daily trigram frequency — "yyyy-MM-dd" -> trigram -> count
    var dailyTrigramCounts: [String: [String: Int]]
    // Per-application keystroke counts — appName -> total count
    var appCounts: [String: Int]
    // Daily per-application keystroke counts — "yyyy-MM-dd" -> appName -> count
    var dailyAppCounts: [String: [String: Int]]
    // Per-device keystroke counts — deviceLabel -> total count
    var deviceCounts: [String: Int]
    // Daily per-device keystroke counts — "yyyy-MM-dd" -> deviceLabel -> count
    var dailyDeviceCounts: [String: [String: Int]]
    // Per-application bigram tracking for ergonomic score computation
    var appSameFingerCount:      [String: Int]   // appName -> cumulative same-finger bigrams
    var appTotalBigramCount:     [String: Int]   // appName -> cumulative total bigrams
    var appHandAlternationCount: [String: Int]   // appName -> cumulative hand-alternating bigrams
    var appHighStrainBigramCount: [String: Int]  // appName -> cumulative high-strain bigrams
    // Per-device bigram tracking for ergonomic score computation
    var deviceSameFingerCount:      [String: Int]   // deviceLabel -> cumulative same-finger bigrams
    var deviceTotalBigramCount:     [String: Int]   // deviceLabel -> cumulative total bigrams
    var deviceHandAlternationCount: [String: Int]   // deviceLabel -> cumulative hand-alternating bigrams
    var deviceHighStrainBigramCount: [String: Int]  // deviceLabel -> cumulative high-strain bigrams
    // Daily shortcut counts (Issue #66) — "yyyy-MM-dd" -> total modifier+key combos that day
    var dailyModifiedCount: [String: Int]

    enum CodingKeys: String, CodingKey {
        case startedAt, counts, dailyCounts
        case lastInputTime, avgIntervalMs, avgIntervalCount
        case modifiedCounts, dailyMinIntervalMs
        case dailyAvgIntervalMs, dailyAvgIntervalCount
        case sameFingerCount, totalBigramCount
        case dailySameFingerCount, dailyTotalBigramCount
        case handAlternationCount, dailyHandAlternationCount
        case hourlyCounts
        case bigramCounts, dailyBigramCounts
        case bigramIKISum, bigramIKICount
        case alternationRewardScore
        case highStrainBigramCount, dailyHighStrainBigramCount
        case highStrainTrigramCount, dailyHighStrainTrigramCount
        case trigramCounts, dailyTrigramCounts
        case appCounts, dailyAppCounts
        case deviceCounts, dailyDeviceCounts
        case appSameFingerCount, appTotalBigramCount
        case appHandAlternationCount, appHighStrainBigramCount
        case deviceSameFingerCount, deviceTotalBigramCount
        case deviceHandAlternationCount, deviceHighStrainBigramCount
        case dailyModifiedCount
    }

    init(startedAt: Date, counts: [String: Int], dailyCounts: [String: [String: Int]]) {
        self.startedAt = startedAt
        self.counts = counts
        self.dailyCounts = dailyCounts
        self.lastInputTime = nil
        self.avgIntervalMs = 0
        self.avgIntervalCount = 0
        self.modifiedCounts = [:]
        self.dailyMinIntervalMs = [:]
        self.dailyAvgIntervalMs    = [:]
        self.dailyAvgIntervalCount = [:]
        self.sameFingerCount = 0
        self.totalBigramCount = 0
        self.dailySameFingerCount = [:]
        self.dailyTotalBigramCount = [:]
        self.handAlternationCount = 0
        self.dailyHandAlternationCount = [:]
        self.hourlyCounts = [:]
        self.bigramCounts = [:]
        self.dailyBigramCounts = [:]
        self.bigramIKISum = [:]
        self.bigramIKICount = [:]
        self.alternationRewardScore = 0
        self.highStrainBigramCount = 0
        self.dailyHighStrainBigramCount = [:]
        self.highStrainTrigramCount = 0
        self.dailyHighStrainTrigramCount = [:]
        self.trigramCounts = [:]
        self.dailyTrigramCounts = [:]
        self.appCounts = [:]
        self.dailyAppCounts = [:]
        self.deviceCounts = [:]
        self.dailyDeviceCounts = [:]
        self.appSameFingerCount = [:]
        self.appTotalBigramCount = [:]
        self.appHandAlternationCount = [:]
        self.appHighStrainBigramCount = [:]
        self.deviceSameFingerCount = [:]
        self.deviceTotalBigramCount = [:]
        self.deviceHandAlternationCount = [:]
        self.deviceHighStrainBigramCount = [:]
        self.dailyModifiedCount = [:]
    }

    /// 旧フォーマット dailyCounts: [String: Int] からのマイグレーション
    /// counts（累計）は保持し、dailyCounts はリセットする
    /// 新フィールド（sameFinger 系）は旧 JSON に存在しないためデフォルト 0 で開始
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        counts    = try c.decode([String: Int].self, forKey: .counts)
        dailyCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyCounts)) ?? [:]
        lastInputTime   = try? c.decode(Date.self, forKey: .lastInputTime)
        avgIntervalMs   = (try? c.decode(Double.self, forKey: .avgIntervalMs)) ?? 0
        avgIntervalCount = (try? c.decode(Int.self, forKey: .avgIntervalCount)) ?? 0
        modifiedCounts  = (try? c.decode([String: Int].self, forKey: .modifiedCounts)) ?? [:]
        dailyMinIntervalMs    = (try? c.decode([String: Double].self, forKey: .dailyMinIntervalMs)) ?? [:]
        dailyAvgIntervalMs    = (try? c.decode([String: Double].self, forKey: .dailyAvgIntervalMs))    ?? [:]
        dailyAvgIntervalCount = (try? c.decode([String: Int].self,    forKey: .dailyAvgIntervalCount)) ?? [:]
        // Same-finger fields: default to 0 when reading old JSON (backward compatible)
        sameFingerCount  = (try? c.decode(Int.self, forKey: .sameFingerCount))  ?? 0
        totalBigramCount = (try? c.decode(Int.self, forKey: .totalBigramCount)) ?? 0
        dailySameFingerCount  = (try? c.decode([String: Int].self, forKey: .dailySameFingerCount))  ?? [:]
        dailyTotalBigramCount = (try? c.decode([String: Int].self, forKey: .dailyTotalBigramCount)) ?? [:]
        // Hand alternation fields: default to 0 when reading old JSON (backward compatible)
        handAlternationCount      = (try? c.decode(Int.self, forKey: .handAlternationCount))          ?? 0
        dailyHandAlternationCount = (try? c.decode([String: Int].self, forKey: .dailyHandAlternationCount)) ?? [:]
        // Hourly counts: default to empty when reading old JSON (backward compatible)
        hourlyCounts = (try? c.decode([String: Int].self, forKey: .hourlyCounts)) ?? [:]
        // Bigram counts: default to empty when reading old JSON (backward compatible)
        bigramCounts = (try? c.decode([String: Int].self, forKey: .bigramCounts)) ?? [:]
        dailyBigramCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyBigramCounts)) ?? [:]
        // Bigram IKI: default to empty when reading old JSON (backward compatible)
        bigramIKISum   = (try? c.decode([String: Double].self, forKey: .bigramIKISum))  ?? [:]
        bigramIKICount = (try? c.decode([String: Int].self,    forKey: .bigramIKICount)) ?? [:]
        // Alternation reward: default to 0 when reading old JSON (backward compatible)
        alternationRewardScore = (try? c.decode(Double.self, forKey: .alternationRewardScore)) ?? 0
        // High-strain fields: default to 0 when reading old JSON (backward compatible)
        highStrainBigramCount        = (try? c.decode(Int.self,            forKey: .highStrainBigramCount))        ?? 0
        dailyHighStrainBigramCount   = (try? c.decode([String: Int].self,  forKey: .dailyHighStrainBigramCount))   ?? [:]
        highStrainTrigramCount       = (try? c.decode(Int.self,            forKey: .highStrainTrigramCount))       ?? 0
        dailyHighStrainTrigramCount  = (try? c.decode([String: Int].self,  forKey: .dailyHighStrainTrigramCount))  ?? [:]
        // Trigram counts: default to empty when reading old JSON (backward compatible)
        trigramCounts      = (try? c.decode([String: Int].self,           forKey: .trigramCounts))      ?? [:]
        dailyTrigramCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyTrigramCounts)) ?? [:]
        appCounts      = (try? c.decode([String: Int].self,            forKey: .appCounts))      ?? [:]
        dailyAppCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyAppCounts)) ?? [:]
        deviceCounts      = (try? c.decode([String: Int].self,            forKey: .deviceCounts))      ?? [:]
        dailyDeviceCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyDeviceCounts)) ?? [:]
        // Per-app bigram ergonomic tracking: default to empty when reading old JSON (backward compatible)
        appSameFingerCount       = (try? c.decode([String: Int].self, forKey: .appSameFingerCount))       ?? [:]
        appTotalBigramCount      = (try? c.decode([String: Int].self, forKey: .appTotalBigramCount))      ?? [:]
        appHandAlternationCount  = (try? c.decode([String: Int].self, forKey: .appHandAlternationCount))  ?? [:]
        appHighStrainBigramCount = (try? c.decode([String: Int].self, forKey: .appHighStrainBigramCount)) ?? [:]
        deviceSameFingerCount       = (try? c.decode([String: Int].self, forKey: .deviceSameFingerCount))       ?? [:]
        deviceTotalBigramCount      = (try? c.decode([String: Int].self, forKey: .deviceTotalBigramCount))      ?? [:]
        deviceHandAlternationCount  = (try? c.decode([String: Int].self, forKey: .deviceHandAlternationCount))  ?? [:]
        deviceHighStrainBigramCount = (try? c.decode([String: Int].self, forKey: .deviceHighStrainBigramCount)) ?? [:]
        // Daily modified count: default to empty when reading old JSON (backward compatible)
        dailyModifiedCount = (try? c.decode([String: Int].self, forKey: .dailyModifiedCount)) ?? [:]
    }
}

// MARK: - Store

/// キーごとのカウントを管理し、JSONファイルに永続化するシングルトン
final class KeyCountStore {
    static let shared = KeyCountStore()

    private var store: CountData
    private let saveURL: URL
    // シリアルキューで排他制御（CGEventTapスレッドとメインスレッドの競合防止）
    private let queue = DispatchQueue(label: "com.keycounter.store")
    private var saveWorkItem: DispatchWorkItem?

    // In-memory only: last key pressed, used for same-finger bigram detection.
    // Not persisted — bigram chains reset on app restart (acceptable for Phase 0).
    private var lastKeyName: String?

    // In-memory only: second-to-last key pressed, used for trigram rolling window (Issue #12).
    // Not persisted — trigram chain resets on app restart (same contract as lastKeyName).
    private var secondLastKeyName: String?

    // In-memory only: whether the previous bigram was high-strain (Issue #28).
    // Used to detect consecutive high-strain bigrams (trigrams). Resets on app restart.
    // 直前のビグラムが高負荷だったかのフラグ。トリグラム検出に使用。再起動でリセット。
    private var lastBigramWasHighStrain: Bool = false

    // In-memory only: consecutive hand-alternating pair count for streak detection (Issue #25).
    // Reset to 0 when a same-hand pair is detected. Mouse clicks / unmapped keys are neutral
    // (they break the bigram chain so no reward fires, but do not reset the streak counter).
    // アプリ再起動でリセット。同手打鍵でゼロクリア。マウスクリックはニュートラル。
    private var alternationStreak: Int = 0

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("counts.json")
        store = CountData(startedAt: Date(), counts: [:], dailyCounts: [:])
        load()
    }

    /// 本日の上位 limit キーを降順で返す
    func todayTopKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync {
            (store.dailyCounts[todayKey] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// 通知間隔（UserDefaults で永続化。デフォルト 1000）
    static var milestoneInterval: Int {
        get { let v = UserDefaults.standard.integer(forKey: "milestoneInterval"); return v > 0 ? v : 1000 }
        set { UserDefaults.standard.set(newValue, forKey: "milestoneInterval") }
    }

    /// カウントを1増やす。milestoneInterval の倍数に達したら milestone = true を返す
    func increment(key: String, at timestamp: Date = Date(), appName: String? = nil) -> (count: Int, milestone: Bool) {
        let today = todayKey
        let hourKey = currentHourKey
        let deviceName = LayoutRegistry.shared.currentDeviceLabel
        let count: Int = queue.sync {
            store.counts[key, default: 0] += 1
            store.dailyCounts[today, default: [:]][key, default: 0] += 1
            // Hourly count (Issue #18)
            store.hourlyCounts[hourKey, default: 0] += 1
            // Per-application count
            if let app = appName {
                store.appCounts[app, default: 0] += 1
                store.dailyAppCounts[today, default: [:]][app, default: 0] += 1
            }
            store.deviceCounts[deviceName, default: 0] += 1
            store.dailyDeviceCounts[today, default: [:]][deviceName, default: 0] += 1

            // Save previous timestamp before updating — needed for per-bigram IKI below.
            let prevInputTime = store.lastInputTime

            // Welford's online algorithm: 1000ms 以内の間隔のみ平均・最小に加算
            if let last = store.lastInputTime {
                let intervalMs = timestamp.timeIntervalSince(last) * 1000
                if intervalMs <= 1000 {
                    // Global Welford update
                    store.avgIntervalCount += 1
                    store.avgIntervalMs += (intervalMs - store.avgIntervalMs) / Double(store.avgIntervalCount)
                    // Daily min interval
                    if intervalMs < (store.dailyMinIntervalMs[today] ?? Double.infinity) {
                        store.dailyMinIntervalMs[today] = intervalMs
                    }
                    // Daily Welford update (Issue #59 Phase 2) — independent per-day accumulator
                    // 日別 Welford 更新：グローバルとは独立した日ごとの累積
                    let dc = store.dailyAvgIntervalCount[today, default: 0] + 1
                    store.dailyAvgIntervalCount[today] = dc
                    let prevAvg = store.dailyAvgIntervalMs[today, default: 0.0]
                    store.dailyAvgIntervalMs[today] = prevAvg + (intervalMs - prevAvg) / Double(dc)
                }
            }
            store.lastInputTime = timestamp

            // Same-finger bigram detection (Issue #16)
            // Both keys must be mapped (mouse clicks return nil and naturally break the chain).
            let layout = LayoutRegistry.shared
            if let prev = lastKeyName,
               let prevFinger = layout.current.finger(for: prev),
               let prevHand   = layout.hand(for: prev),
               let curFinger  = layout.current.finger(for: key),
               let curHand    = layout.hand(for: key) {
                store.totalBigramCount += 1
                store.dailyTotalBigramCount[today, default: 0] += 1
                if prevFinger == curFinger && prevHand == curHand {
                    store.sameFingerCount += 1
                    store.dailySameFingerCount[today, default: 0] += 1
                }
                // Hand alternation detection (Issue #17) + reward accumulation (Issue #25)
                if prevHand != curHand {
                    store.handAlternationCount += 1
                    store.dailyHandAlternationCount[today, default: 0] += 1
                    alternationStreak += 1
                    store.alternationRewardScore +=
                        layout.alternationRewardModel.reward(forStreak: alternationStreak)
                } else {
                    alternationStreak = 0
                }
                // Raw bigram pair frequency (Issue #12)
                let pair = "\(prev)→\(key)"
                store.bigramCounts[pair, default: 0] += 1
                store.dailyBigramCounts[today, default: [:]][pair, default: 0] += 1
                // Bigram IKI accumulation (Issue #24) — only within the 1000ms typing window.
                // ビグラムごとの IKI を蓄積（校正データ収集フック）。
                if let prevTime = prevInputTime {
                    let iki = timestamp.timeIntervalSince(prevTime) * 1000
                    if iki <= 1000 {
                        store.bigramIKISum[pair, default: 0]   += iki
                        store.bigramIKICount[pair, default: 0] += 1
                    }
                }
                // High-strain sequence detection (Issue #28) — same finger + ≥1 row distance.
                // 高負荷ビグラム検出（同指かつ縦1行以上の移動）。
                let highStrain = layout.highStrainDetector.isHighStrain(from: prev, to: key, layout: layout)
                if highStrain {
                    store.highStrainBigramCount += 1
                    store.dailyHighStrainBigramCount[today, default: 0] += 1
                    // Trigram: two consecutive high-strain bigrams.
                    // トリグラム：高負荷ビグラムが連続した場合。
                    if lastBigramWasHighStrain {
                        store.highStrainTrigramCount += 1
                        store.dailyHighStrainTrigramCount[today, default: 0] += 1
                    }
                }
                lastBigramWasHighStrain = highStrain
                // Per-app bigram ergonomic tracking
                if let app = appName {
                    store.appTotalBigramCount[app, default: 0] += 1
                    if prevFinger == curFinger && prevHand == curHand {
                        store.appSameFingerCount[app, default: 0] += 1
                    }
                    if prevHand != curHand {
                        store.appHandAlternationCount[app, default: 0] += 1
                    }
                    if highStrain {
                        store.appHighStrainBigramCount[app, default: 0] += 1
                    }
                }
                store.deviceTotalBigramCount[deviceName, default: 0] += 1
                if prevFinger == curFinger && prevHand == curHand {
                    store.deviceSameFingerCount[deviceName, default: 0] += 1
                }
                if prevHand != curHand {
                    store.deviceHandAlternationCount[deviceName, default: 0] += 1
                }
                if highStrain {
                    store.deviceHighStrainBigramCount[deviceName, default: 0] += 1
                }
                // General trigram frequency (Issue #12) — 3-key rolling window.
                // Only records when secondLastKeyName is available (3rd key onwards).
                // 3キーのローリングウィンドウ。3キー目以降からトリグラムを記録する。
                if let prev2 = secondLastKeyName {
                    let trigram = "\(prev2)→\(prev)→\(key)"
                    store.trigramCounts[trigram, default: 0] += 1
                    store.dailyTrigramCounts[today, default: [:]][trigram, default: 0] += 1
                }
                // Advance window only when both keys are valid mapped keys.
                // prev is already validated by the guard above.
                // 両キーがマップ済みの場合のみウィンドウを前進する。
                secondLastKeyName = prev
            } else {
                // Chain broken (unmapped key, mouse click) — reset trigram window to prevent
                // stale prev2 from polluting a future trigram across an interruption.
                // チェーン切断時はウィンドウをリセット。未マップキーをまたいだ誤トリグラムを防ぐ。
                secondLastKeyName = nil
            }
            lastKeyName = key

            // Daily goal notification check (Issue #69)
            checkGoalNotificationLocked(todayStr: today)

            return store.counts[key, default: 0]
        }
        scheduleSave()
        return (count, count % KeyCountStore.milestoneInterval == 0)
    }

    /// 平均入力間隔（ms）。サンプルが1件以上あれば返す
    var averageIntervalMs: Double? {
        queue.sync { store.avgIntervalCount > 0 ? store.avgIntervalMs : nil }
    }

    /// 推定タイピング速度（WPM）。1 word = 5 keystrokes の標準定義に基づく。
    /// Estimated typing speed in WPM. Based on the standard definition: 1 word = 5 keystrokes.
    var estimatedWPM: Double? {
        guard let ms = averageIntervalMs, ms > 0 else { return nil }
        return 60_000.0 / (ms * 5.0)
    }

    /// Backspace (Delete) 率（累計）。全打鍵数に占める Delete キーの割合（%）。
    /// Cumulative backspace rate: Delete count / total keystrokes × 100 (%).
    var backspaceRate: Double? {
        queue.sync {
            let total = store.counts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return Double(store.counts["Delete", default: 0]) / Double(total) * 100.0
        }
    }

    /// 本日の Backspace 率（%）。
    /// Today's backspace rate (%).
    var todayBackspaceRate: Double? {
        queue.sync {
            let dayCounts = store.dailyCounts[todayKey] ?? [:]
            let total = dayCounts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return Double(dayCounts["Delete", default: 0]) / Double(total) * 100.0
        }
    }

    /// 日別 Backspace 率を昇順（古い日付順）で返す。打鍵数が0の日は除外。
    /// Returns per-day backspace rate sorted ascending. Days with zero keystrokes are excluded.
    func dailyBackspaceRates() -> [(date: String, rate: Double)] {
        queue.sync {
            store.dailyCounts.compactMap { date, dayCounts -> (date: String, rate: Double)? in
                let total = dayCounts.values.reduce(0, +)
                guard total > 0 else { return nil }
                let bs = dayCounts["Delete", default: 0]
                return (date, Double(bs) / Double(total) * 100.0)
            }
            .sorted { $0.date < $1.date }
        }
    }

    /// 日別推定 WPM を昇順（古い日付順）で返す。蓄積データがある日のみ含む。
    /// Returns per-day estimated WPM sorted by date ascending. Only days with accumulated data are included.
    func dailyWPM() -> [(date: String, wpm: Double)] {
        queue.sync {
            store.dailyAvgIntervalMs.compactMap { date, avgMs -> (date: String, wpm: Double)? in
                guard let count = store.dailyAvgIntervalCount[date], count > 0, avgMs > 0 else { return nil }
                return (date, 60_000.0 / (avgMs * 5.0))
            }
            .sorted { $0.date < $1.date }
        }
    }

    /// 本日の最小入力間隔（ms, 1000ms以内のみ）。サンプルが1件以上あれば返す
    var todayMinIntervalMs: Double? {
        let key = todayKey
        return queue.sync { store.dailyMinIntervalMs[key] }
    }

    /// 同指連続打鍵率（累計）。サンプルが1件以上あれば返す
    var sameFingerRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.sameFingerCount) / Double(store.totalBigramCount)
        }
    }

    /// 本日の同指連続打鍵率。サンプルが1件以上あれば返す
    var todaySameFingerRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            let same = store.dailySameFingerCount[today] ?? 0
            return Double(same) / Double(total)
        }
    }

    /// 左右交互打鍵率（累計）。サンプルが1件以上あれば返す
    var handAlternationRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.handAlternationCount) / Double(store.totalBigramCount)
        }
    }

    /// 本日の左右交互打鍵率。サンプルが1件以上あれば返す
    var todayHandAlternationRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            let alt = store.dailyHandAlternationCount[today] ?? 0
            return Double(alt) / Double(total)
        }
    }

    /// Cumulative alternation reward score (Issue #25).
    /// Includes streak multiplier bonus for runs of ≥3 consecutive alternating pairs.
    /// 交互打鍵報酬の累積スコア（ストリーク乗数ボーナスを含む）。
    var alternationRewardScore: Double {
        queue.sync { store.alternationRewardScore }
    }

    /// Cumulative thumb imbalance ratio (Issue #26).
    /// Returns nil if no thumb keystrokes have been recorded.
    /// 累積親指偏り比率。親指打鍵が0件の場合は nil。
    var thumbImbalanceRatio: Double? {
        queue.sync {
            LayoutRegistry.shared.thumbImbalanceDetector
                .imbalanceRatio(counts: store.counts, layout: LayoutRegistry.shared)
        }
    }

    /// Thumb imbalance ratio for a specific day (Issue #26).
    /// Returns nil if no thumb keystrokes were recorded on that day.
    /// 指定日の親指偏り比率。当日の親指打鍵が0件の場合は nil。
    func dailyThumbImbalance(for date: String) -> Double? {
        queue.sync {
            guard let dayCounts = store.dailyCounts[date] else { return nil }
            return LayoutRegistry.shared.thumbImbalanceDetector
                .imbalanceRatio(counts: dayCounts, layout: LayoutRegistry.shared)
        }
    }

    /// Per-day ergonomic rates for Learning Curve visualization (Phase 3).
    /// Returns rows only for dates that have at least one bigram recorded.
    /// 各日の人間工学指標率。ビグラムが1件以上ある日のみ返す。
    func dailyErgonomicRates() -> [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)] {
        queue.sync {
            store.dailyCounts.keys.sorted().compactMap { date in
                let bigrams = store.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { return nil }
                let sf = Double(store.dailySameFingerCount[date]       ?? 0) / Double(bigrams)
                let ha = Double(store.dailyHandAlternationCount[date]  ?? 0) / Double(bigrams)
                let hs = Double(store.dailyHighStrainBigramCount[date] ?? 0) / Double(bigrams)
                return (date: date, sameFingerRate: sf, handAltRate: ha, highStrainRate: hs)
            }
        }
    }

    /// Cumulative high-strain bigram count (Issue #28).
    /// 累積高負荷ビグラム数。
    var highStrainBigramCount: Int {
        queue.sync { store.highStrainBigramCount }
    }

    /// Fraction of all bigrams that are high-strain (Issue #28).
    /// Returns nil if no bigrams have been recorded.
    /// 全ビグラムに対する高負荷ビグラムの割合。ビグラムが0件の場合は nil。
    var highStrainBigramRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.highStrainBigramCount) / Double(store.totalBigramCount)
        }
    }

    /// Cumulative high-strain trigram count (Issue #28).
    /// 累積高負荷トリグラム数。
    var highStrainTrigramCount: Int {
        queue.sync { store.highStrainTrigramCount }
    }

    /// Top-N high-strain bigrams by frequency (Issue #28).
    /// Filters bigramCounts using HighStrainDetector at read time.
    /// 頻度上位 N 件の高負荷ビグラムを返す。読み取り時に HighStrainDetector でフィルタ。
    func topHighStrainBigrams(limit: Int = 10) -> [(pair: String, count: Int)] {
        queue.sync {
            let detector = LayoutRegistry.shared.highStrainDetector
            let layout   = LayoutRegistry.shared
            return store.bigramCounts
                .filter { pair, _ in
                    let parts = pair.components(separatedBy: "→")
                    guard parts.count == 2 else { return false }
                    return detector.isHighStrain(from: parts[0], to: parts[1], layout: layout)
                }
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { (pair: $0.key, count: $0.value) }
        }
    }

    /// Thumb efficiency coefficient (Issue #27).
    /// Returns nil if no keystrokes have been recorded.
    /// 親指効率係数。打鍵データが0件の場合は nil。
    var thumbEfficiencyCoefficient: Double? {
        queue.sync {
            LayoutRegistry.shared.thumbEfficiencyCalculator
                .coefficient(counts: store.counts, layout: LayoutRegistry.shared)
        }
    }

    /// Unified ergonomic score (0–100) computed from cumulative keystroke data (Issue #29).
    /// Higher is better. Returns 100.0 when no bigram data is available.
    ///
    /// Formula (all sub-scores normalised to [0, 100]):
    ///   score = 100
    ///     - 0.30 × sameFingerRate×100
    ///     - 0.25 × highStrainRate×100
    ///     - 0.15 × thumbImbalanceRatio×100
    ///     + 0.20 × handAlternationRate×100
    ///     + 0.10 × min(thumbEfficiency/2, 1)×100
    ///
    /// 累積打鍵データから算出した統合エルゴノミクススコア (0–100)。高いほど良好。
    var currentErgonomicScore: Double {
        queue.sync {
            let engine = LayoutRegistry.shared.ergonomicScoreEngine
            let layout = LayoutRegistry.shared
            let bigrams = store.totalBigramCount

            let sfbRate = bigrams > 0
                ? Double(store.sameFingerCount) / Double(bigrams) : 0.0
            let hsRate  = bigrams > 0
                ? Double(store.highStrainBigramCount) / Double(bigrams) : 0.0
            let altRate = bigrams > 0
                ? Double(store.handAlternationCount) / Double(bigrams) : 0.0
            let tiRatio = layout.thumbImbalanceDetector
                .imbalanceRatio(counts: store.counts, layout: layout) ?? 0.0
            let teCoeff = layout.thumbEfficiencyCalculator
                .coefficient(counts: store.counts, layout: layout) ?? 0.0

            return engine.score(
                sameFingerRate:             sfbRate,
                highStrainRate:             hsRate,
                thumbImbalanceRatio:        tiRatio,
                handAlternationRate:        altRate,
                thumbEfficiencyCoefficient: teCoeff
            )
        }
    }

    /// Inferred typing style based on cumulative data.
    /// 累積データから推定された現在のタイピングスタイル。
    public var currentTypingStyle: TypingStyle {
        queue.sync {
            TypingStyleAnalyzer().analyze(keyCounts: store.counts)
        }
    }

    /// Detected fatigue risk level.
    /// 判定された疲労リスク。
    public var currentFatigueLevel: FatigueLevel {
        queue.sync {
            let bigrams = store.totalBigramCount
            let hsRate = bigrams > 0 ? Double(store.highStrainBigramCount) / Double(bigrams) : 0.0
            
            return FatigueRiskModel().analyze(
                currentAvgIntervalMs:   nil, // TODO: Implement windowed speed check
                baselineAvgIntervalMs:  nil,
                currentHighStrainRate:  hsRate,
                baselineHighStrainRate: 0.02
            )
        }
    }

    /// Per-day ergonomic scores for trend tracking (Issue #29).
    /// Keys are "yyyy-MM-dd" strings. Only dates with at least one bigram are included.
    ///
    /// 日別エルゴノミクススコア。ビグラムが1件以上ある日のみ含む。
    var dailyErgonomicScore: [String: Double] {
        queue.sync {
            let engine = LayoutRegistry.shared.ergonomicScoreEngine
            let layout = LayoutRegistry.shared
            var result: [String: Double] = [:]

            for date in store.dailyCounts.keys {
                let bigrams = store.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { continue }

                let sfbRate = Double(store.dailySameFingerCount[date]       ?? 0) / Double(bigrams)
                let hsRate  = Double(store.dailyHighStrainBigramCount[date] ?? 0) / Double(bigrams)
                let altRate = Double(store.dailyHandAlternationCount[date]  ?? 0) / Double(bigrams)
                let dayCounts = store.dailyCounts[date] ?? [:]
                let tiRatio = layout.thumbImbalanceDetector
                    .imbalanceRatio(counts: dayCounts, layout: layout) ?? 0.0
                let teCoeff = layout.thumbEfficiencyCalculator
                    .coefficient(counts: dayCounts, layout: layout) ?? 0.0

                result[date] = engine.score(
                    sameFingerRate:             sfbRate,
                    highStrainRate:             hsRate,
                    thumbImbalanceRatio:        tiRatio,
                    handAlternationRate:        altRate,
                    thumbEfficiencyCoefficient: teCoeff
                )
            }
            return result
        }
    }

    /// 指定日の時間帯別打鍵数を返す（24要素、hour 0〜23）
    /// date は "yyyy-MM-dd" 形式。データがない時間帯は 0
    func hourlyCounts(for date: String) -> [Int] {
        queue.sync {
            (0..<24).map { hour in
                let key = String(format: "%@-%02d", date, hour)
                return store.hourlyCounts[key] ?? 0
            }
        }
    }

    /// 修飾キー+キーの組み合わせカウントを1増やす
    func incrementModified(key: String) {
        queue.sync {
            store.modifiedCounts[key, default: 0] += 1
            store.dailyModifiedCount[todayKey, default: 0] += 1
        }
        scheduleSave()
    }

    /// Shortcut efficiency for today: shortcuts / (shortcuts + mouse clicks), or nil if no data.
    func shortcutEfficiencyToday() -> Double? {
        queue.sync {
            let shortcuts = store.dailyModifiedCount[todayKey] ?? 0
            let dayCounts = store.dailyCounts[todayKey] ?? [:]
            let mouseClicks = dayCounts.filter { $0.key.hasPrefix("🖱") }.values.reduce(0, +)
            let total = shortcuts + mouseClicks
            guard total > 0 else { return nil }
            return Double(shortcuts) / Double(total) * 100.0
        }
    }

    /// 修飾キー付きコンボの上位 limit 件を返す。prefix 指定で前方一致フィルタ
    func topModifiedKeys(prefix: String = "", limit: Int = 20) -> [(key: String, count: Int)] {
        queue.sync {
            store.modifiedCounts
                .filter { prefix.isEmpty || $0.key.hasPrefix(prefix) }
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// 本日（ローカル時刻）のキー入力合計
    var todayCount: Int {
        queue.sync { store.dailyCounts[todayKey]?.values.reduce(0, +) ?? 0 }
    }

    // MARK: - Daily Goal & Streak

    private static let dailyGoalKey    = "dailyGoalCount"
    private static let goalNotifiedKey = "goalNotifiedDate"

    /// Daily keystroke goal. 0 = off. Persisted in UserDefaults.
    /// 1日の目標打鍵数。0 = オフ。UserDefaults に永続化。
    var dailyGoal: Int {
        get { UserDefaults.standard.integer(forKey: Self.dailyGoalKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.dailyGoalKey) }
    }

    /// Inner streak calculation — must be called inside queue.sync.
    /// queue.sync 内部から呼ぶ前提の内部メソッド。
    private func streakLocked(goal: Int) -> Int {
        var streak = 0
        let cal = Calendar.current
        var date = Date()
        for _ in 0..<365 {
            let key = Self.dayFormatter.string(from: date)
            let count = store.dailyCounts[key]?.values.reduce(0, +) ?? 0
            if count >= goal {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Current streak: consecutive days (including today if goal met) where daily total >= dailyGoal.
    /// 目標達成した連続日数（今日を含む）。dailyGoal == 0 の場合は 0。
    func currentStreak() -> Int {
        let goal = dailyGoal
        guard goal > 0 else { return 0 }
        return queue.sync { streakLocked(goal: goal) }
    }

    /// Check if today's goal was just crossed and fire a one-per-day notification if so.
    /// Called inside queue.sync from increment().
    /// 今日初めて目標を超えた場合に通知を発火する（increment() 内から呼ぶ）。
    private func checkGoalNotificationLocked(todayStr: String) {
        let goal = dailyGoal
        guard goal > 0 else { return }
        let notified = UserDefaults.standard.string(forKey: Self.goalNotifiedKey)
        guard notified != todayStr else { return }
        let todayTotal = store.dailyCounts[todayStr]?.values.reduce(0, +) ?? 0
        guard todayTotal >= goal else { return }
        UserDefaults.standard.set(todayStr, forKey: Self.goalNotifiedKey)
        let streak = streakLocked(goal: goal)
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = L10n.shared.goalReachedTitle
            content.body  = L10n.shared.goalReachedBody(streak: streak)
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: "com.keylens.goalReached",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(req) { _ in }
        }
    }

    /// Returns per-day keystroke totals for the last N calendar days (oldest first).
    /// 直近 N 日分の日別合計打鍵数を古い順で返す。
    func dailyTotals(last days: Int) -> [(date: String, count: Int)] {
        let cal = Calendar.current
        return queue.sync {
            (0..<days).reversed().compactMap { offset -> (String, Int)? in
                guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
                let key = Self.dayFormatter.string(from: date)
                let count = store.dailyCounts[key]?.values.reduce(0, +) ?? 0
                return (key, count)
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HH"
        return f
    }()

    private var todayKey: String { Self.dayFormatter.string(from: Date()) }
    private var currentHourKey: String { Self.hourFormatter.string(from: Date()) }

    /// カウント上位 limit 件を降順で返す
    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync {
            store.counts.sorted { $0.value > $1.value }
                        .prefix(limit)
                        .map { ($0.key, $0.value) }
        }
    }

    /// 累計アプリ別打鍵数の上位 limit 件を降順で返す
    func topApps(limit: Int = 20) -> [(app: String, count: Int)] {
        queue.sync {
            store.appCounts.sorted { $0.value > $1.value }
                           .prefix(limit)
                           .map { ($0.key, $0.value) }
        }
    }
    
    /// 累計デバイス別打鍵数の上位 limit 件を降順で返す
    func topDevices(limit: Int = 20) -> [(device: String, count: Int)] {
        queue.sync {
            store.deviceCounts.sorted { $0.value > $1.value }
                              .prefix(limit)
                              .map { ($0.key, $0.value) }
        }
    }

    /// Per-app ergonomic scores for apps with at least minKeystrokes total keystrokes.
    /// Returns entries sorted by score descending.
    /// minKeystrokes 以上打鍵があるアプリのエルゴノミクススコアを降順で返す。
    func appErgonomicScores(minKeystrokes: Int = 100) -> [(app: String, score: Double, keystrokes: Int)] {
        queue.sync {
            let engine = LayoutRegistry.shared.ergonomicScoreEngine
            return store.appCounts
                .filter { $0.value >= minKeystrokes }
                .compactMap { (app, keystrokes) -> (app: String, score: Double, keystrokes: Int)? in
                    let bigrams = store.appTotalBigramCount[app] ?? 0
                    guard bigrams > 0 else { return nil }
                    let sfRate  = Double(store.appSameFingerCount[app]       ?? 0) / Double(bigrams)
                    let hsRate  = Double(store.appHighStrainBigramCount[app] ?? 0) / Double(bigrams)
                    let altRate = Double(store.appHandAlternationCount[app]  ?? 0) / Double(bigrams)
                    let score = engine.score(
                        sameFingerRate:             sfRate,
                        highStrainRate:             hsRate,
                        thumbImbalanceRatio:        0.0,  // not tracked per-app
                        handAlternationRate:        altRate,
                        thumbEfficiencyCoefficient: 0.0   // not tracked per-app
                    )
                    return (app: app, score: score, keystrokes: keystrokes)
                }
                .sorted { $0.score > $1.score }
        }
    }
    
    /// Per-device ergonomic scores for devices with at least minKeystrokes total keystrokes.
    /// Returns entries sorted by score descending.
    /// minKeystrokes 以上打鍵があるデバイスのエルゴノミクススコアを降順で返す。
    func deviceErgonomicScores(minKeystrokes: Int = 100) -> [(device: String, score: Double, keystrokes: Int)] {
        queue.sync {
            let engine = LayoutRegistry.shared.ergonomicScoreEngine
            return store.deviceCounts
                .filter { $0.value >= minKeystrokes }
                .compactMap { (device, keystrokes) -> (device: String, score: Double, keystrokes: Int)? in
                    let bigrams = store.deviceTotalBigramCount[device] ?? 0
                    guard bigrams > 0 else { return nil }
                    let sfRate  = Double(store.deviceSameFingerCount[device]       ?? 0) / Double(bigrams)
                    let hsRate  = Double(store.deviceHighStrainBigramCount[device] ?? 0) / Double(bigrams)
                    let altRate = Double(store.deviceHandAlternationCount[device]  ?? 0) / Double(bigrams)
                    let score = engine.score(
                        sameFingerRate:             sfRate,
                        highStrainRate:             hsRate,
                        thumbImbalanceRatio:        0.0,
                        handAlternationRate:        altRate,
                        thumbEfficiencyCoefficient: 0.0
                    )
                    return (device: device, score: score, keystrokes: keystrokes)
                }
                .sorted { $0.score > $1.score }
        }
    }

    /// 本日のアプリ別打鍵数の上位 limit 件を降順で返す
    func todayTopApps(limit: Int = 10) -> [(app: String, count: Int)] {
        queue.sync {
            (store.dailyAppCounts[todayKey] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }
    
    /// 本日のデバイス別打鍵数の上位 limit 件を降順で返す
    func todayTopDevices(limit: Int = 10) -> [(device: String, count: Int)] {
        queue.sync {
            (store.dailyDeviceCounts[todayKey] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Full cumulative bigram frequency table ("k1→k2" format). Used by ErgonomicSnapshot / LayoutComparison.
    /// 累積ビグラム頻度テーブル全件。ErgonomicSnapshot / LayoutComparison で使用。
    var allBigramCounts: [String: Int] {
        queue.sync { store.bigramCounts }
    }

    /// Full cumulative per-key keystroke counts. Used for thumb imbalance and efficiency metrics.
    /// 累積キー別打鍵数テーブル全件。親指偏り・効率指標の計算に使用。
    var allKeyCounts: [String: Int] {
        queue.sync { store.counts }
    }

    /// 累計ビグラム上位 limit 件を降順で返す (Issue #12)
    func topBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync {
            store.bigramCounts.sorted { $0.value > $1.value }
                              .prefix(limit)
                              .map { ($0.key, $0.value) }
        }
    }

    /// 本日のビグラム上位 limit 件を降順で返す (Issue #12)
    func todayTopBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            (store.dailyBigramCounts[today] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Top-N trigrams by cumulative frequency (Issue #12)
    func topTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync {
            store.trigramCounts.sorted { $0.value > $1.value }
                               .prefix(limit)
                               .map { ($0.key, $0.value) }
        }
    }

    /// Top-N trigrams for today (Issue #12)
    func todayTopTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            (store.dailyTrigramCounts[today] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Returns the average IKI (ms) for a bigram, or nil if no samples exist.
    /// Use this to derive empirical distance factors for SameFingerPenalty calibration:
    ///   factor(tier) ≈ avgIKI(same-finger bigram in tier) / avgIKI(reference bigram)
    /// ビグラムの平均 IKI（ms）を返す。SameFingerPenalty 距離係数の実測校正に使用。
    func avgBigramIKI(for bigram: String) -> Double? {
        queue.sync {
            guard let count = store.bigramIKICount[bigram], count > 0 else { return nil }
            return store.bigramIKISum[bigram].map { $0 / Double(count) }
        }
    }

    /// サマリー CSV（rank,key,total）を返す
    func exportSummaryCSV() -> String {
        queue.sync {
            var lines = ["rank,key,total"]
            for (i, (key, total)) in store.counts.sorted(by: { $0.value > $1.value }).enumerated() {
                let escaped = key.contains(",") ? "\"\(key)\"" : key
                lines.append("\(i + 1),\(escaped),\(total)")
            }
            return lines.joined(separator: "\n")
        }
    }

    /// 日別 CSV（date,key,count）を返す
    func exportDailyCSV() -> String {
        queue.sync {
            var lines = ["date,key,count"]
            for date in store.dailyCounts.keys.sorted() {
                let dayCounts = store.dailyCounts[date] ?? [:]
                for (key, count) in dayCounts.sorted(by: { $0.value > $1.value }) {
                    let escaped = key.contains(",") ? "\"\(key)\"" : key
                    lines.append("\(date),\(escaped),\(count)")
                }
            }
            return lines.joined(separator: "\n")
        }
    }

    /// 日別合計入力数を返す（日付昇順）
    func dailyTotals() -> [(date: String, total: Int)] {
        queue.sync {
            store.dailyCounts
                .map { (date: $0.key, total: $0.value.values.reduce(0, +)) }
                .sorted { $0.date < $1.date }
        }
    }

    /// Aggregate hourly keystroke counts across all recorded dates.
    /// Returns a 24-element array where index = hour of day (0–23).
    /// 全日付にわたる時間帯別打鍵数の集計。インデックスが時刻（0〜23）。
    func hourlyDistribution() -> [Int] {
        queue.sync {
            var result = [Int](repeating: 0, count: 24)
            for (key, count) in store.hourlyCounts {
                // key format: "yyyy-MM-dd-HH"
                let parts = key.split(separator: "-")
                guard parts.count == 4, let hour = Int(parts[3]), hour < 24 else { continue }
                result[hour] += count
            }
            return result
        }
    }

    /// Aggregate total keystrokes by calendar month ("yyyy-MM"), sorted ascending.
    /// 月別（yyyy-MM）打鍵数合計。昇順ソート済み。
    func monthlyTotals() -> [(month: String, total: Int)] {
        queue.sync {
            var monthMap: [String: Int] = [:]
            for (date, keyCounts) in store.dailyCounts {
                // date format: "yyyy-MM-dd" → month prefix = first 7 chars
                guard date.count >= 7 else { continue }
                let month = String(date.prefix(7))
                monthMap[month, default: 0] += keyCounts.values.reduce(0, +)
            }
            return monthMap
                .map { (month: $0.key, total: $0.value) }
                .sorted { $0.month < $1.month }
        }
    }

    /// キータイプ別の累計カウントを返す（多い順）
    func countsByType() -> [(type: KeyType, count: Int)] {
        queue.sync {
            var totals: [KeyType: Int] = [:]
            for (key, count) in store.counts {
                totals[KeyType.classify(key), default: 0] += count
            }
            return KeyType.allCases
                .compactMap { t in totals[t].map { (type: t, count: $0) } }
                .filter { $0.count > 0 }
                .sorted { $0.count > $1.count }
        }
    }

    /// 直近 recentDays 日間の上位 limit キーを (date, key, count) で返す
    func topKeysPerDay(limit: Int = 10, recentDays: Int = 14) -> [(date: String, key: String, count: Int)] {
        queue.sync {
            let dates = Array(store.dailyCounts.keys.sorted().suffix(recentDays))
            // 対象期間の合算で上位 limit キーを決定
            var combined: [String: Int] = [:]
            for date in dates {
                for (k, v) in store.dailyCounts[date] ?? [:] {
                    combined[k, default: 0] += v
                }
            }
            let topKeyNames = combined.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
            var result: [(date: String, key: String, count: Int)] = []
            for date in dates {
                let dayCounts = store.dailyCounts[date] ?? [:]
                for key in topKeyNames {
                    result.append((date: date, key: key, count: dayCounts[key] ?? 0))
                }
            }
            return result
        }
    }

    /// 全キー・ボタンを累計降順で返す（total / today の両方を含む）
    func allEntries() -> [(key: String, total: Int, today: Int)] {
        queue.sync {
            let todayData = store.dailyCounts[todayKey] ?? [:]
            return store.counts.sorted { $0.value > $1.value }
                .map { (key: $0.key, total: $0.value, today: todayData[$0.key] ?? 0) }
        }
    }

    var totalCount: Int {
        queue.sync { store.counts.values.reduce(0, +) }
    }

    /// 記録開始日時
    var startedAt: Date {
        queue.sync { store.startedAt }
    }

    /// カウントと開始日を今日にリセットする
    func reset() {
        queue.sync {
            store = CountData(startedAt: Date(), counts: [:], dailyCounts: [:])
            lastKeyName = nil
            secondLastKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
            // CountData.init already zeros handAlternationCount / alternationRewardScore / highStrainCounts
        }
        scheduleSave()
    }

    // MARK: - Persistence

    /// 2秒以内の連続呼び出しをまとめて1回の書き込みに集約する
    /// 新しい入力があるたびに「2秒後の保存予約」をキャンセルして作り直す。
    /// これにより、タイピング中は保存が走らず、手が止まった瞬間にだけディスクに書き込まれるという、
    /// 効率的な仕組み
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = item
        queue.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if var decoded = try? decoder.decode(CountData.self, from: data) {
            // Retention policy (Issue #18): prune hourlyCounts entries older than 365 days.
            // Key format is "yyyy-MM-dd-HH"; prefix(10) yields "yyyy-MM-dd" for comparison.
            if let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: Date()) {
                let cutoff = Self.dayFormatter.string(from: cutoffDate)
                decoded.hourlyCounts = decoded.hourlyCounts.filter { $0.key.prefix(10) >= cutoff }
            }
            store = decoded
        }
    }
}
