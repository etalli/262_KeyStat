import Foundation

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

    enum CodingKeys: String, CodingKey {
        case startedAt, counts, dailyCounts
        case lastInputTime, avgIntervalMs, avgIntervalCount
        case modifiedCounts
    }

    init(startedAt: Date, counts: [String: Int], dailyCounts: [String: [String: Int]]) {
        self.startedAt = startedAt
        self.counts = counts
        self.dailyCounts = dailyCounts
        self.lastInputTime = nil
        self.avgIntervalMs = 0
        self.avgIntervalCount = 0
        self.modifiedCounts = [:]
    }

    /// 旧フォーマット dailyCounts: [String: Int] からのマイグレーション
    /// counts（累計）は保持し、dailyCounts はリセットする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        counts    = try c.decode([String: Int].self, forKey: .counts)
        dailyCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyCounts)) ?? [:]
        lastInputTime   = try? c.decode(Date.self, forKey: .lastInputTime)
        avgIntervalMs   = (try? c.decode(Double.self, forKey: .avgIntervalMs)) ?? 0
        avgIntervalCount = (try? c.decode(Int.self, forKey: .avgIntervalCount)) ?? 0
        modifiedCounts  = (try? c.decode([String: Int].self, forKey: .modifiedCounts)) ?? [:]
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

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyStat")
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

    /// カウントを1増やす。1000の倍数に達したら milestone = true を返す
    func increment(key: String, at timestamp: Date = Date()) -> (count: Int, milestone: Bool) {
        let today = todayKey
        let count: Int = queue.sync {
            store.counts[key, default: 0] += 1
            store.dailyCounts[today, default: [:]][key, default: 0] += 1
            // Welford's online algorithm: 1000ms 以内の間隔のみ平均に加算
            if let last = store.lastInputTime {
                let intervalMs = timestamp.timeIntervalSince(last) * 1000
                if intervalMs <= 1000 {
                    store.avgIntervalCount += 1
                    store.avgIntervalMs += (intervalMs - store.avgIntervalMs) / Double(store.avgIntervalCount)
                }
            }
            store.lastInputTime = timestamp
            return store.counts[key, default: 0]
        }
        scheduleSave()
        return (count, count % 1000 == 0)
    }

    /// 平均入力間隔（ms）。サンプルが1件以上あれば返す
    var averageIntervalMs: Double? {
        queue.sync { store.avgIntervalCount > 0 ? store.avgIntervalMs : nil }
    }

    /// 修飾キー+キーの組み合わせカウントを1増やす
    func incrementModified(key: String) {
        queue.sync { store.modifiedCounts[key, default: 0] += 1 }
        scheduleSave()
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

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    /// カウント上位 limit 件を降順で返す
    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync {
            store.counts.sorted { $0.value > $1.value }
                        .prefix(limit)
                        .map { ($0.key, $0.value) }
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
        }
        scheduleSave()
    }

    // MARK: - Persistence

    /// 2秒以内の連続呼び出しをまとめて1回の書き込みに集約する
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
        if let decoded = try? decoder.decode(CountData.self, from: data) {
            store = decoded
        }
    }
}
