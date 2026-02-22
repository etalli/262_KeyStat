import Foundation

// MARK: - Data model

/// 永続化するデータ全体。startedAt でいつから記録を開始したかを保持する
private struct CountData: Codable {
    var startedAt: Date
    var counts: [String: Int]
    var dailyCounts: [String: [String: Int]]   // "yyyy-MM-dd" -> keyName -> count

    enum CodingKeys: String, CodingKey {
        case startedAt, counts, dailyCounts
    }

    init(startedAt: Date, counts: [String: Int], dailyCounts: [String: [String: Int]]) {
        self.startedAt = startedAt
        self.counts = counts
        self.dailyCounts = dailyCounts
    }

    /// 旧フォーマット dailyCounts: [String: Int] からのマイグレーション
    /// counts（累計）は保持し、dailyCounts はリセットする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        counts    = try c.decode([String: Int].self, forKey: .counts)
        dailyCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyCounts)) ?? [:]
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
            .appendingPathComponent("KeyCounter")
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
    func increment(key: String) -> (count: Int, milestone: Bool) {
        let today = todayKey
        let count: Int = queue.sync {
            store.counts[key, default: 0] += 1
            store.dailyCounts[today, default: [:]][key, default: 0] += 1
            return store.counts[key, default: 0]
        }
        scheduleSave()
        return (count, count % 1000 == 0)
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
