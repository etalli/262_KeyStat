import Foundation
import GRDB

/// SQLite-backed store for mouse movement metrics.
/// Accumulates movement in-memory and flushes to disk every 30 seconds.
/// Keyboard data (counts.json) is unaffected by this store.
///
/// マウス移動メトリクスを SQLite に保存するストア。
/// 移動量はメモリ内で蓄積し、30秒ごとにディスクへフラッシュする。
/// キーボードデータ (counts.json) には影響しない。
///
/// Database file: ~/Library/Application Support/KeyLens/mouse.db
final class MouseStore {
    static let shared = MouseStore()

    private var dbQueue: DatabaseQueue?
    private let queue = DispatchQueue(label: "com.keylens.mousestore", qos: .utility)

    // In-memory accumulators — protected by `queue`
    private var pendingDistance: Double = 0
    private var pendingDxPos: Double = 0   // rightward sum
    private var pendingDxNeg: Double = 0   // leftward sum (positive value)
    private var pendingDyPos: Double = 0   // downward sum
    private var pendingDyNeg: Double = 0   // upward sum (positive value)

    private var flushTimer: DispatchSourceTimer?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        setupDatabase()
        startFlushTimer()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let dir = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("KeyLens")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbPath = dir.appendingPathComponent("mouse.db").path

            let db = try DatabaseQueue(path: dbPath)

            var migrator = DatabaseMigrator()
            migrator.registerMigration("v1") { db in
                // Daily aggregates: total distance + directional breakdown
                // 日次集計: 総移動距離 + 方向別内訳
                try db.create(table: "mouse_daily", ifNotExists: true) { t in
                    t.primaryKey("date", .text)
                    t.column("distance_pts", .double).notNull().defaults(to: 0)
                    t.column("dx_pos", .double).notNull().defaults(to: 0)
                    t.column("dx_neg", .double).notNull().defaults(to: 0)
                    t.column("dy_pos", .double).notNull().defaults(to: 0)
                    t.column("dy_neg", .double).notNull().defaults(to: 0)
                }
                // Hourly aggregates: for time-of-day breakdown
                // 時間別集計: 時間帯分析用
                try db.create(table: "mouse_hourly", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("hour", .integer).notNull()
                    t.column("distance_pts", .double).notNull().defaults(to: 0)
                    t.primaryKey(["date", "hour"])
                }
            }
            try migrator.migrate(db)

            dbQueue = db
            KeyLens.log("MouseStore: database ready at \(dbPath)")
        } catch {
            KeyLens.log("MouseStore: failed to initialize database: \(error)")
        }
    }

    // MARK: - Accumulation

    /// Accumulate a single mouse movement event.
    /// Hot path: addition only, zero disk I/O.
    ///
    /// マウス移動イベントを蓄積する（ホットパス: 加算のみ、ディスクI/Oなし）。
    func addMovement(dx: Double, dy: Double) {
        queue.async { [self] in
            let dist = (dx * dx + dy * dy).squareRoot()
            pendingDistance += dist
            if dx > 0 { pendingDxPos += dx  } else { pendingDxNeg += -dx }
            if dy > 0 { pendingDyPos += dy  } else { pendingDyNeg += -dy }
        }
    }

    // MARK: - Flush

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in self?.flushLocked() }
        timer.resume()
        flushTimer = timer
    }

    /// Flush pending data to SQLite. Must be called on `queue`.
    /// 保留中のデータを SQLite へフラッシュする。`queue` 上で呼ぶこと。
    private func flushLocked() {
        guard pendingDistance > 0, let db = dbQueue else { return }

        let dist  = pendingDistance
        let dxPos = pendingDxPos
        let dxNeg = pendingDxNeg
        let dyPos = pendingDyPos
        let dyNeg = pendingDyNeg
        pendingDistance = 0; pendingDxPos = 0; pendingDxNeg = 0
        pendingDyPos    = 0; pendingDyNeg = 0

        let dateStr = Self.dayFormatter.string(from: Date())
        let hour    = Calendar.current.component(.hour, from: Date())

        do {
            try db.write { db in
                try db.execute(sql: """
                    INSERT INTO mouse_daily (date, distance_pts, dx_pos, dx_neg, dy_pos, dy_neg)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        distance_pts = distance_pts + excluded.distance_pts,
                        dx_pos       = dx_pos       + excluded.dx_pos,
                        dx_neg       = dx_neg       + excluded.dx_neg,
                        dy_pos       = dy_pos       + excluded.dy_pos,
                        dy_neg       = dy_neg       + excluded.dy_neg
                    """, arguments: [dateStr, dist, dxPos, dxNeg, dyPos, dyNeg])

                try db.execute(sql: """
                    INSERT INTO mouse_hourly (date, hour, distance_pts)
                    VALUES (?, ?, ?)
                    ON CONFLICT(date, hour) DO UPDATE SET
                        distance_pts = distance_pts + excluded.distance_pts
                    """, arguments: [dateStr, hour, dist])
            }
        } catch {
            KeyLens.log("MouseStore: flush error: \(error)")
        }
    }

    /// Synchronous flush — call on app termination to avoid data loss.
    func flushSync() {
        queue.sync { flushLocked() }
    }

    // MARK: - Queries

    /// Total mouse travel distance for today in points (screen coordinates).
    /// Returns nil if no data has been recorded yet.
    /// Includes in-memory pending distance not yet flushed to disk.
    func distanceToday() -> Double? {
        queue.sync {
            let dateStr = Self.dayFormatter.string(from: Date())
            var stored: Double = 0
            if let db = dbQueue {
                stored = (try? db.read { db in
                    try Double.fetchOne(db, sql: "SELECT distance_pts FROM mouse_daily WHERE date = ?",
                                        arguments: [dateStr])
                }) ?? 0
            }
            let total = stored + pendingDistance
            return total > 0 ? total : nil
        }
    }
}
