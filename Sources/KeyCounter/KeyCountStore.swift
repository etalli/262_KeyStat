import Foundation

// MARK: - Data model

/// 永続化するデータ全体。startedAt でいつから記録を開始したかを保持する
private struct CountData: Codable {
    var startedAt: Date
    var counts: [String: Int]
}

// MARK: - Store

/// キーごとのカウントを管理し、JSONファイルに永続化するシングルトン
final class KeyCountStore {
    static let shared = KeyCountStore()

    private var store: CountData
    private let saveURL: URL
    // シリアルキューで排他制御（CGEventTapスレッドとメインスレッドの競合防止）
    private let queue = DispatchQueue(label: "com.keycounter.store")

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyCounter")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("counts.json")
        store = CountData(startedAt: Date(), counts: [:])
        load()
    }

    /// カウントを1増やす。1000の倍数に達したら milestone = true を返す
    func increment(key: String) -> (count: Int, milestone: Bool) {
        var count = 0
        queue.sync {
            store.counts[key, default: 0] += 1
            count = store.counts[key]!
        }
        queue.async { self.save() }
        return (count, count % 1000 == 0)
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

    // MARK: - Persistence

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

        // 新フォーマット（startedAt + counts）を試みる
        if let decoded = try? decoder.decode(CountData.self, from: data) {
            store = decoded
            return
        }

        // 旧フォーマット（[String: Int] のみ）からマイグレーション
        if let counts = try? decoder.decode([String: Int].self, from: data) {
            store = CountData(startedAt: Date(), counts: counts)
            save()  // 新フォーマットで上書き保存
        }
    }
}
