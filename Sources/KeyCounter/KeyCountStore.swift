import Foundation

/// キーごとのカウントを管理し、JSONファイルに永続化するシングルトン
final class KeyCountStore {
    static let shared = KeyCountStore()

    private var counts: [String: Int] = [:]
    private let saveURL: URL
    // シリアルキューで排他制御（CGEventTapスレッドとメインスレッドの競合防止）
    private let queue = DispatchQueue(label: "com.keycounter.store")

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyCounter")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("counts.json")
        load()
    }

    /// カウントを1増やす。1000の倍数に達したら milestone = true を返す
    func increment(key: String) -> (count: Int, milestone: Bool) {
        var count = 0
        queue.sync {
            counts[key, default: 0] += 1
            count = counts[key]!
        }
        queue.async { self.save() }
        return (count, count % 1000 == 0)
    }

    /// カウント上位 limit 件を降順で返す
    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync {
            counts.sorted { $0.value > $1.value }
                  .prefix(limit)
                  .map { ($0.key, $0.value) }
        }
    }

    var totalCount: Int {
        queue.sync { counts.values.reduce(0, +) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(counts) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return }
        counts = decoded
    }
}
