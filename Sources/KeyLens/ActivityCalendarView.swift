import SwiftUI

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
