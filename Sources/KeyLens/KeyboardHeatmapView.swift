import SwiftUI

// MARK: - KeyDef

private struct KeyDef {
    let label: String       // 表示ラベル
    let keyName: String     // KeyCountStore の counts キー名
    let widthRatio: Double  // 標準キー(1.0) に対する相対幅

    init(_ label: String, _ keyName: String, _ widthRatio: Double) {
        self.label = label
        self.keyName = keyName
        self.widthRatio = widthRatio
    }
}

// MARK: - KeyboardHeatmapView

struct KeyboardHeatmapView: View {
    let counts: [String: Int]

    private let keyHeight: CGFloat = 40
    private let keySpacing: CGFloat = 4

    // US 配列レイアウト（各行の幅比合計 = 15U）
    private static let rows: [[KeyDef]] = [
        // Number row (15U)
        [
            .init("~\n`",  "`",      1.0),
            .init("1",     "1",      1.0), .init("2", "2", 1.0), .init("3", "3", 1.0),
            .init("4",     "4",      1.0), .init("5", "5", 1.0), .init("6", "6", 1.0),
            .init("7",     "7",      1.0), .init("8", "8", 1.0), .init("9", "9", 1.0),
            .init("0",     "0",      1.0), .init("-", "-", 1.0), .init("=", "=", 1.0),
            .init("⌫",     "Delete", 2.0),
        ],
        // QWERTY row (15U)
        [
            .init("⇥",     "Tab",    1.5),
            .init("Q",     "q",      1.0), .init("W", "w", 1.0), .init("E", "e", 1.0),
            .init("R",     "r",      1.0), .init("T", "t", 1.0), .init("Y", "y", 1.0),
            .init("U",     "u",      1.0), .init("I", "i", 1.0), .init("O", "o", 1.0),
            .init("P",     "p",      1.0), .init("[", "[", 1.0), .init("]", "]", 1.0),
            .init("\\",    "\\",     1.5),
        ],
        // Home row (15U)
        [
            .init("⇪",     "CapsLock", 1.75),
            .init("A",     "a",        1.0), .init("S", "s", 1.0), .init("D", "d", 1.0),
            .init("F",     "f",        1.0), .init("G", "g", 1.0), .init("H", "h", 1.0),
            .init("J",     "j",        1.0), .init("K", "k", 1.0), .init("L", "l", 1.0),
            .init(";",     ";",        1.0), .init("'", "'", 1.0),
            .init("↩",     "Return",   2.25),
        ],
        // Shift row (15U)
        [
            .init("⇧",     "⇧Shift",  2.25),
            .init("Z",     "z",        1.0), .init("X", "x", 1.0), .init("C", "c", 1.0),
            .init("V",     "v",        1.0), .init("B", "b", 1.0), .init("N", "n", 1.0),
            .init("M",     "m",        1.0), .init(",", ",", 1.0), .init(".", ".", 1.0),
            .init("/",     "/",        1.0),
            .init("⇧",     "⇧Shift",  2.75),
        ],
        // Bottom row (15U)
        [
            .init("⌃", "⌃Ctrl",   1.5),
            .init("⌥", "⌥Option", 1.5),
            .init("⌘", "⌘Cmd",    1.5),
            .init("Space", "Space", 7.5),
            .init("⌘", "⌘Cmd",    1.5),
            .init("⌥", "⌥Option", 1.5),
            .init("⌃", "⌃Ctrl",   1.5),
        ],
    ]

    // キーボードキー名を static に事前計算（毎レンダリングで生成しない）
    private static let keyboardKeyNames = Set(rows.flatMap { $0 }.map(\.keyName))

    // 接続中キーボード名（ウィンドウ表示時に一度だけ取得）
    private let deviceNames: [String] = KeyboardDeviceInfo.connectedNames()

    private var maxKeyCount: Int {
        counts.filter { Self.keyboardKeyNames.contains($0.key) }.values.max() ?? 1
    }

    private var maxMouseCount: Int {
        counts.filter { $0.key.hasPrefix("🖱") }.values.max() ?? 1
    }

    // マウスボタン一覧（データ準備を View から分離）
    private var mouseButtons: [KeyDef] {
        let fixed: [KeyDef] = [
            .init("🖱 Left",   "🖱Left",   1.0),
            .init("🖱 Middle", "🖱Middle", 1.0),
            .init("🖱 Right",  "🖱Right",  1.0),
        ]
        let knownKeys: Set<String> = ["🖱Left", "🖱Right", "🖱Middle"]
        let extra = counts.keys
            .filter { $0.hasPrefix("🖱") && !knownKeys.contains($0) }
            .sorted()
            .map { KeyDef($0, $0, 1.0) }
        return fixed + extra
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 接続中キーボード名
            if !deviceNames.isEmpty {
                Text(deviceNames.joined(separator: "  /  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let availableWidth = geo.size.width - 16  // padding 8pt × 2
                VStack(alignment: .leading, spacing: keySpacing) {
                    ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                        rowView(row, availableWidth: availableWidth)
                    }
                }
                .padding(8)
            }
            .frame(height: CGFloat(Self.rows.count) * (keyHeight + keySpacing) - keySpacing + 16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.01))

            mouseSection
            legend
        }
    }

    // MARK: - Keyboard row

    @ViewBuilder
    private func rowView(_ row: [KeyDef], availableWidth: CGFloat) -> some View {
        let totalRatio = row.map(\.widthRatio).reduce(0, +)
        let gaps = CGFloat(row.count - 1) * keySpacing
        let unitWidth = (availableWidth - gaps) / CGFloat(totalRatio)

        HStack(spacing: keySpacing) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                heatCell(
                    label: key.label,
                    count: counts[key.keyName] ?? 0,
                    max: maxKeyCount,
                    width: unitWidth * key.widthRatio
                )
            }
        }
    }

    // MARK: - Mouse section

    private var mouseSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.shared.heatmapMouse)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: keySpacing) {
                ForEach(Array(mouseButtons.enumerated()), id: \.offset) { _, key in
                    heatCell(
                        label: key.label,
                        count: counts[key.keyName] ?? 0,
                        max: maxMouseCount,
                        width: 80
                    )
                }
            }
        }
    }

    // MARK: - Shared cell view

    private func heatCell(label: String, count: Int, max: Int, width: CGFloat) -> some View {
        let bgColor = heatColor(count: count, max: max)
        let fgColor: Color = count > 0 ? .white : Color(white: 0.5)

        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(bgColor)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(fgColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
        }
        .frame(width: width, height: keyHeight)
    }

    // MARK: - Legend

    private var legend: some View {
        let l = L10n.shared
        return HStack(spacing: 6) {
            Text(l.heatmapLow)
                .font(.caption2)
                .foregroundStyle(.secondary)
            LinearGradient(
                stops: [
                    .init(color: Color(white: 0.25),                                   location: 0.00),
                    .init(color: Color(hue: 0.67, saturation: 0.75, brightness: 0.82), location: 0.15),
                    .init(color: Color(hue: 0.40, saturation: 0.75, brightness: 0.82), location: 0.45),
                    .init(color: Color(hue: 0.15, saturation: 0.75, brightness: 0.82), location: 0.75),
                    .init(color: Color(hue: 0.00, saturation: 0.75, brightness: 0.82), location: 1.00),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(l.heatmapHigh)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Color

    // 青(低) → 緑 → 黄 → 赤(高)
    private func heatColor(count: Int, max: Int) -> Color {
        guard max > 0, count > 0 else { return Color(white: 0.25) }
        let t = Double(count) / Double(max)
        let hue = (1.0 - t) * 0.67  // 0.67(青) → 0.0(赤)
        return Color(hue: hue, saturation: 0.75, brightness: 0.82)
    }
}
