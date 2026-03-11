import SwiftUI

// MARK: - HeatmapMode

enum HeatmapMode: String, CaseIterable {
    case frequency = "Frequency"
    case strain    = "Strain"
}

// MARK: - HeatmapTemplate

enum HeatmapTemplate: String, CaseIterable {
    case ansi        = "ANSI"
    case pangaea     = "Pangaea"
    case ortholinear = "Ortho"
}

private enum HeatmapTooltipStyle {
    case count
    case strain
}

// MARK: - KeyDef

struct KeyDef {
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

    @State private var mode: HeatmapMode = .frequency
    @State private var selectedCellID: String?
    @State private var showModeHelp: Bool = false
    @State private var showStrainLegendHelp: Bool = false
    @State private var copyConfirmed = false
    @AppStorage("heatmapTemplate") private var template: HeatmapTemplate = .ansi
    @ObservedObject private var theme = ThemeStore.shared
    @Environment(\.colorScheme) private var colorScheme

    // Adapts to dark / light mode — dark: near-black, light: near-white
    private var emptyKeyColor: Color { colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85) }

    private let keyHeight: CGFloat = 40
    private let keySpacing: CGFloat = 4

    // US 配列レイアウト（各行の幅比合計 = 15U）
    static let ansiRows: [[KeyDef]] = [
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

    // MARK: Pangaea split ergo layout (docs/Pangaea.json)
    // Each side has 4 alpha rows + 1 thumb row (6U per row).
    // "_spacer_" keyName renders as an invisible padding cell.
    // Pangaea スプリットエルゴノミクスレイアウト。各サイド 4 行 + サムロー（6U）。
    // "_spacer_" は不可視パディングセル。

    static let pangaeaLeftRows: [[KeyDef]] = [
        // Row 0: Number row (6U)
        [.init("~\nEsc", "Escape", 1), .init("1", "1", 1), .init("2", "2", 1),
         .init("3", "3", 1),           .init("4", "4", 1), .init("5", "5", 1)],
        // Row 1: QWERTY (6U)
        [.init("⇥", "Tab", 1), .init("Q", "q", 1), .init("W", "w", 1),
         .init("E", "e",   1), .init("R", "r", 1), .init("T", "t", 1)],
        // Row 2: Home row (6U)
        [.init("⌃", "⌃Ctrl", 1), .init("A", "a", 1), .init("S", "s", 1),
         .init("D", "d",     1), .init("F", "f", 1), .init("G", "g", 1)],
        // Row 3: Bottom row (6U)
        [.init("⇧", "⇧Shift", 1), .init("Z", "z", 1), .init("X", "x", 1),
         .init("C", "c",      1), .init("V", "v", 1), .init("B", "b", 1)],
        // Row 4: Thumb row (6U — left thumb: ⌘ Upper ⌫ DEL, padded with spacers)
        [.init("", "_spacer_", 1), .init("⌘", "⌘Cmd",   1), .init("↑", "Upper",  1),
         .init("⌫", "Delete", 1), .init("DEL", "Del",    1), .init("", "_spacer_", 1)],
    ]

    static let pangaeaRightRows: [[KeyDef]] = [
        // Row 0: Number row (6U)
        [.init("6", "6", 1), .init("7", "7", 1), .init("8", "8", 1),
         .init("9", "9", 1), .init("0", "0", 1), .init("-", "-", 1)],
        // Row 1: YUIOP (6U)
        [.init("Y", "y", 1), .init("U", "u", 1), .init("I", "i", 1),
         .init("O", "o", 1), .init("P", "p", 1), .init("=", "=", 1)],
        // Row 2: Home row (6U)
        [.init("H", "h", 1), .init("J", "j", 1), .init("K", "k", 1),
         .init("L", "l", 1), .init(";", ";", 1), .init("'", "'", 1)],
        // Row 3: Bottom row (6U)
        [.init("N", "n", 1), .init("M", "m", 1), .init(",", ",", 1),
         .init(".", ".", 1), .init("/", "/", 1), .init("⇧", "⇧Shift", 1)],
        // Row 4: Thumb row (6U — right thumb: ↩ SPC Lower, padded with spacers)
        [.init("", "_spacer_", 1), .init("↩", "Return",  1),
         .init("SPC", "Space", 1), .init("↓", "Lower",   1), .init("", "_spacer_", 2)],
    ]

    // MARK: Ortholinear layout (generic 60% grid — all keys 1U except Space 6U)
    // Row width = 12U. Keys missing from standard ANSI ([ ] \ ' - =) are omitted.
    // オーソリニア（60%グリッド）レイアウト。Space 以外はすべて 1U。
    static let ortholinearRows: [[KeyDef]] = [
        // Row 0: Number row (12U)
        [.init("~\n`", "`",      1), .init("1", "1", 1), .init("2", "2", 1),
         .init("3",    "3",      1), .init("4", "4", 1), .init("5", "5", 1),
         .init("6",    "6",      1), .init("7", "7", 1), .init("8", "8", 1),
         .init("9",    "9",      1), .init("0", "0", 1), .init("⌫", "Delete", 1)],
        // Row 1: QWERTY (12U)
        [.init("⇥", "Tab", 1), .init("Q", "q", 1), .init("W", "w", 1),
         .init("E",  "e",  1), .init("R", "r", 1), .init("T", "t", 1),
         .init("Y",  "y",  1), .init("U", "u", 1), .init("I", "i", 1),
         .init("O",  "o",  1), .init("P", "p", 1), .init("⌫", "Delete", 1)],
        // Row 2: Home row (12U)
        [.init("⇪", "CapsLock", 1), .init("A", "a", 1), .init("S", "s", 1),
         .init("D",  "d",       1), .init("F", "f", 1), .init("G", "g", 1),
         .init("H",  "h",       1), .init("J", "j", 1), .init("K", "k", 1),
         .init("L",  "l",       1), .init(";", ";", 1), .init("↩", "Return", 1)],
        // Row 3: Shift row (12U)
        [.init("⇧", "⇧Shift", 1), .init("Z", "z", 1), .init("X", "x", 1),
         .init("C",  "c",     1), .init("V", "v", 1), .init("B", "b", 1),
         .init("N",  "n",     1), .init("M", "m", 1), .init(",", ",", 1),
         .init(".",  ".",     1), .init("/", "/", 1), .init("⇧", "⇧Shift", 1)],
        // Row 4: Thumb / space row (12U — Space is 6U)
        [.init("⌃", "⌃Ctrl",   1), .init("⌥", "⌥Option", 1), .init("⌘", "⌘Cmd", 1),
         .init("Space", "Space", 6),
         .init("⌘", "⌘Cmd",    1), .init("⌥", "⌥Option", 1), .init("⌃", "⌃Ctrl", 1)],
    ]

    // キーボードキー名をテンプレートに応じて動的に計算する（instance computed property）
    // Template-aware keyboard key names; computed per-render from active template.
    private var keyboardKeyNames: Set<String> {
        let defs: [KeyDef]
        switch template {
        case .ansi:
            defs = Self.ansiRows.flatMap { $0 }
        case .pangaea:
            defs = (Self.pangaeaLeftRows + Self.pangaeaRightRows).flatMap { $0 }
        case .ortholinear:
            defs = Self.ortholinearRows.flatMap { $0 }
        }
        return Set(defs.map(\.keyName)).subtracting(["_spacer_"])
    }

    // 接続中キーボード名（ウィンドウ表示時に一度だけ取得）
    private let deviceNames: [String] = KeyboardDeviceInfo.connectedNames()

    private var maxKeyCount: Int {
        counts.filter { keyboardKeyNames.contains($0.key) }.values.max() ?? 1
    }

    private var maxMouseCount: Int {
        counts.filter { $0.key.hasPrefix("🖱") }.values.max() ?? 1
    }

    // Strain score per key: sum of high-strain bigram counts in which the key participates.
    // キーごとの高負荷スコア：そのキーが関係する高負荷ビグラムのカウント合計。
    private var strainScores: [String: Int] {
        var scores: [String: Int] = [:]
        for (pair, count) in KeyCountStore.shared.topHighStrainBigrams(limit: 1000) {
            let parts = pair.components(separatedBy: "→")
            guard parts.count == 2 else { continue }
            scores[parts[0], default: 0] += count
            scores[parts[1], default: 0] += count
        }
        return scores
    }

    private var maxStrainScore: Int { strainScores.values.max() ?? 1 }

    // Returns (count, max) for a key based on the current display mode.
    // 現在の表示モードに応じてキーの（カウント, 最大値）ペアを返す。
    private func keyDisplayValues(for keyName: String) -> (Int, Int) {
        switch mode {
        case .frequency: return (counts[keyName] ?? 0, maxKeyCount)
        case .strain:    return (strainScores[keyName] ?? 0, maxStrainScore)
        }
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
            // Template + mode controls
            VStack(alignment: .leading, spacing: 6) {
                // Layout template selector
                HStack {
                    Picker("", selection: $template) {
                        ForEach(HeatmapTemplate.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    Spacer()
                }
                // Mode toggle + connected keyboard names
                HStack {
                    Picker("", selection: $mode) {
                        ForEach(HeatmapMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)

                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(showModeHelp ? .primary : .secondary)
                        .onHover { showModeHelp = $0 }
                        .popover(isPresented: $showModeHelp, arrowEdge: .bottom) {
                            Text(mode == .strain
                                ? L10n.shared.helpHeatmapStrain
                                : L10n.shared.helpHeatmapFrequency
                            )
                            .font(.callout)
                            .padding(10)
                            .frame(width: 280)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                    Button(action: exportAsPNG) {
                        Label(L10n.shared.exportHeatmap, systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: copyToClipboard) {
                        Label(copyConfirmed ? L10n.shared.copiedConfirmation : L10n.shared.copyHeatmap,
                              systemImage: copyConfirmed ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    if !deviceNames.isEmpty {
                        Text(deviceNames.joined(separator: "  /  "))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }  // end mode HStack
            }  // end controls VStack

            HeatmapExportView(
                counts: counts,
                mode: mode,
                template: template,
                keyboardKeyNames: keyboardKeyNames,
                strainScores: strainScores,
                selectedCellID: $selectedCellID
            )
        }
    }

    // MARK: - Export Logic

    @MainActor
    private func exportAsPNG() {
        let view = HeatmapExportView(
            counts: counts,
            mode: mode,
            template: template,
            keyboardKeyNames: keyboardKeyNames,
            strainScores: strainScores
        )
        .frame(width: 800) // Base width for export
        .background(Color(NSColor.windowBackgroundColor))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // Retain scale

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "KeyLens_Heatmap_\(mode.rawValue).png"

        if panel.runModal() == .OK, let url = panel.url {
            if let image = renderer.nsImage {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }

    @MainActor
    private func copyToClipboard() {
        let view = HeatmapExportView(
            counts: counts,
            mode: mode,
            template: template,
            keyboardKeyNames: keyboardKeyNames,
            strainScores: strainScores
        )
        .frame(width: 800)
        .background(Color(NSColor.windowBackgroundColor))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        guard let image = renderer.nsImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        copyConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copyConfirmed = false
        }
    }
}

// MARK: - HeatmapExportView

struct HeatmapExportView: View {
    let counts: [String: Int]
    let mode: HeatmapMode
    let template: HeatmapTemplate
    let keyboardKeyNames: Set<String>
    let strainScores: [String: Int]
    var selectedCellID: Binding<String?>? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var emptyKeyColor: Color { colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85) }

    private let keyHeight: CGFloat = 40
    private let keySpacing: CGFloat = 4

    private var maxKeyCount: Int {
        counts.filter { keyboardKeyNames.contains($0.key) }.values.max() ?? 1
    }

    private var maxMouseCount: Int {
        counts.filter { $0.key.hasPrefix("🖱") }.values.max() ?? 1
    }

    private var maxStrainScore: Int { strainScores.values.max() ?? 1 }

    private func keyDisplayValues(for keyName: String) -> (Int, Int) {
        switch mode {
        case .frequency: return (counts[keyName] ?? 0, maxKeyCount)
        case .strain:    return (strainScores[keyName] ?? 0, maxStrainScore)
        }
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let availableWidth = geo.size.width - 16
                VStack(alignment: .leading, spacing: keySpacing) {
                    switch template {
                    case .ansi, .ortholinear:
                        let activeRows = template == .ansi ? KeyboardHeatmapView.ansiRows : KeyboardHeatmapView.ortholinearRows
                        ForEach(Array(activeRows.enumerated()), id: \.offset) { rowIndex, row in
                            rowView(row, rowID: "row-\(rowIndex)", availableWidth: availableWidth)
                        }
                    case .pangaea:
                        let splitGap: CGFloat = 20
                        let halfWidth = (availableWidth - splitGap) / 2
                        ForEach(KeyboardHeatmapView.pangaeaLeftRows.indices, id: \.self) { i in
                            HStack(spacing: splitGap) {
                                rowView(KeyboardHeatmapView.pangaeaLeftRows[i], rowID: "left-\(i)", availableWidth: halfWidth)
                                rowView(KeyboardHeatmapView.pangaeaRightRows[i], rowID: "right-\(i)", availableWidth: halfWidth)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: CGFloat(5) * (keyHeight + keySpacing) - keySpacing + 16)

            mouseSection
            legend
        }
        .padding(10)
    }

    @ViewBuilder
    private func rowView(_ row: [KeyDef], rowID: String, availableWidth: CGFloat) -> some View {
        let totalRatio = row.map(\.widthRatio).reduce(0, +)
        let gaps = CGFloat(row.count - 1) * keySpacing
        let unitWidth = (availableWidth - gaps) / CGFloat(totalRatio)

        HStack(spacing: keySpacing) {
            ForEach(Array(row.enumerated()), id: \.offset) { idx, key in
                if key.keyName == "_spacer_" {
                    Color.clear.frame(width: unitWidth * CGFloat(key.widthRatio), height: keyHeight)
                } else {
                    let (displayCount, displayMax) = keyDisplayValues(for: key.keyName)
                    heatCell(
                        cellID: "\(rowID)-\(idx)-\(key.keyName)",
                        label: key.label,
                        count: displayCount,
                        max: displayMax,
                        width: unitWidth * CGFloat(key.widthRatio),
                        tooltipStyle: mode == .strain ? .strain : .count
                    )
                }
            }
        }
    }

    private var mouseSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.shared.heatmapMouse)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: keySpacing) {
                ForEach(Array(mouseButtons.enumerated()), id: \.offset) { idx, key in
                    heatCell(
                        cellID: "mouse-\(idx)-\(key.keyName)",
                        label: key.label,
                        count: counts[key.keyName] ?? 0,
                        max: maxMouseCount,
                        width: 80,
                        tooltipStyle: .count
                    )
                }
            }
        }
    }

    private func heatCell(
        cellID: String,
        label: String,
        count: Int,
        max: Int,
        width: CGFloat,
        tooltipStyle: HeatmapTooltipStyle
    ) -> some View {
        let t = max > 0 && count > 0 ? Double(count) / Double(max) : 0
        let baseHue = ThemeStore.shared.current.heatmapBaseHue
        let hue = (1.0 - t) * baseHue
        let bgColor = count > 0 ? Color(hue: hue, saturation: 0.75, brightness: 0.82) : emptyKeyColor
        let fgColor: Color = count > 0 ? .white : .secondary

        let cell = ZStack {
            RoundedRectangle(cornerRadius: 5).fill(bgColor)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(fgColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
        }
        .frame(width: width, height: keyHeight)

        guard let selectedCellID else { return AnyView(cell) }

        let isPresented = Binding(
            get: { selectedCellID.wrappedValue == cellID },
            set: { if !$0 { selectedCellID.wrappedValue = nil } }
        )

        return AnyView(
            cell
                .contentShape(RoundedRectangle(cornerRadius: 5))
                .onTapGesture {
                    selectedCellID.wrappedValue = cellID
                }
                .popover(isPresented: isPresented, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tooltipText(for: count, style: tooltipStyle))
                            .font(.callout.monospacedDigit())
                    }
                    .padding(10)
                }
        )
    }

    private func tooltipText(for value: Int, style: HeatmapTooltipStyle) -> String {
        switch style {
        case .count:
            return L10n.shared.heatmapCountTooltip(value)
        case .strain:
            return L10n.shared.heatmapStrainTooltip(value)
        }
    }

    private var legend: some View {
        let l = L10n.shared
        let lowLabel  = mode == .strain ? "Low strain"  : l.heatmapLow
        let highLabel = mode == .strain ? "High strain" : l.heatmapHigh
        return HStack(spacing: 6) {
            Text(lowLabel).font(.caption2).foregroundStyle(.secondary)
            LinearGradient(
                stops: {
                    let h = ThemeStore.shared.current.heatmapBaseHue
                    return [
                        .init(color: emptyKeyColor, location: 0.00),
                        .init(color: Color(hue: h,            saturation: 0.75, brightness: 0.82), location: 0.15),
                        .init(color: Color(hue: h * 0.60,     saturation: 0.75, brightness: 0.82), location: 0.45),
                        .init(color: Color(hue: h * 0.22,     saturation: 0.75, brightness: 0.82), location: 0.75),
                        .init(color: Color(hue: 0.00,          saturation: 0.75, brightness: 0.82), location: 1.00),
                    ]
                }(),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(highLabel).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
