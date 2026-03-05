import Foundation

// MARK: - Language

enum Language: String, CaseIterable {
    case system   = "system"
    case english  = "en"
    case japanese = "ja"

    var displayName: String {
        switch self {
        case .system:   return "Auto"
        case .english:  return "English"
        case .japanese: return "日本語"
        }
    }
}

// MARK: - L10n

/// アプリ内のローカライズ文字列を一元管理するシングルトン
/// 言語設定は UserDefaults に永続化し、再起動後も保持される
final class L10n {
    static let shared = L10n()
    private let defaultsKey = "appLanguage"

    private init() {}

    /// 現在の言語設定（system / en / ja）
    var language: Language {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? Language.system.rawValue
            return Language(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    /// 実際に使用する言語（system の場合は Locale から解決）
    var resolved: Language {
        guard language == .system else { return language }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code == "ja" ? .japanese : .english
    }

    // MARK: - Strings

    var totalFormat: String {
        ja("合計: %@ 入力", en: "Total: %@ inputs")
    }

    var todayFormat: String {
        ja("本日: %@ 入力", en: "Today: %@ inputs")
    }

    var noInput: String {
        ja("（まだ入力なし）", en: "(no input yet)")
    }

    var monitoringActive: String {
        ja("● 監視中", en: "● Monitoring")
    }

    var monitoringStopped: String {
        ja("● 停止中 — クリックして設定を開く", en: "● Stopped — click to open Settings")
    }

    var restartTitle: String {
        ja("再起動が必要です", en: "Restart Required")
    }

    var restartMessage: String {
        ja(
            "アクセシビリティ権限は付与されましたが、有効にするには KeyLens の再起動が必要です。",
            en: "Accessibility permission was granted, but KeyLens must restart to activate monitoring."
        )
    }

    var restartNow: String {
        ja("今すぐ再起動", en: "Restart Now")
    }

    var openSaveFolder: String {
        ja("保存先を開く", en: "Open Log Folder")
    }

    var launchAtLogin: String {
        ja("ログイン時に起動", en: "Launch at Login")
    }

    var resetMenuItem: String {
        ja("リセット…", en: "Reset…")
    }

    var resetAlertTitle: String {
        ja("カウントをリセットしますか？", en: "Reset all counts?")
    }

    var resetAlertMessage: String {
        ja(
            "すべてのキーカウントと記録開始日が本日にリセットされます。この操作は取り消せません。",
            en: "All key counts and the start date will be reset to today. This cannot be undone."
        )
    }

    var resetConfirmButton: String {
        ja("リセット", en: "Reset")
    }

    var cancel: String {
        ja("キャンセル", en: "Cancel")
    }

    var quit: String {
        ja("終了", en: "Quit")
    }

    var settingsMenuTitle: String {
        ja("設定…", en: "Settings…")
    }

    var aboutMenuItem: String {
        ja("KeyLens について", en: "About KeyLens")
    }

    var close: String {
        ja("閉じる", en: "Close")
    }

    var heatmapLow: String {
        ja("少", en: "Low")
    }

    var heatmapHigh: String {
        ja("多", en: "High")
    }

    var heatmapMouse: String {
        ja("マウス", en: "Mouse")
    }

    var languageMenuTitle: String {
        ja("言語", en: "Language")
    }

    var accessibilityTitle: String {
        ja("アクセシビリティ権限が必要です", en: "Accessibility Permission Required")
    }

    var accessibilityMessage: String {
        ja(
            "キー入力を監視するには、アクセシビリティ権限が必要です。\n「システム設定 → プライバシーとセキュリティ → アクセシビリティ」で\nKeyLens を許可してください。",
            en: "KeyLens needs Accessibility permission to monitor keystrokes.\nGo to System Settings > Privacy & Security > Accessibility\nand enable KeyLens."
        )
    }

    var openSystemSettings: String {
        ja("システム設定を開く", en: "Open System Settings")
    }

    var later: String {
        ja("あとで", en: "Later")
    }

    var showAllMenuItem: String {
        ja("全件表示…", en: "Show All…")
    }

    var chartsMenuItem: String {
        ja("グラフ表示…", en: "Show Charts…")
    }

    var overlayMenuItem: String {
        ja("キーオーバーレイ", en: "Keystroke Overlay")
    }

    var overlaySettingsMenuItem: String {
        ja("オーバーレイ設定…", en: "Overlay Settings…")
    }

    var overlaySettingsWindowTitle: String {
        ja("キーオーバーレイ設定", en: "Keystroke Overlay Settings")
    }

    var overlaySettingsPosition: String {
        ja("表示位置", en: "Position")
    }

    var overlayPositionTopLeft: String {
        ja("左上", en: "Top Left")
    }

    var overlayPositionTopRight: String {
        ja("右上", en: "Top Right")
    }

    var overlayPositionBottomLeft: String {
        ja("左下", en: "Bottom Left")
    }

    var overlayPositionBottomRight: String {
        ja("右下", en: "Bottom Right")
    }

    var overlaySettingsFadeDelay: String {
        ja("フェード持続時間", en: "Fade Delay")
    }

    func overlayFadeDelayLabel(_ sec: Double) -> String {
        let s = Int(sec)
        return ja("\(s)秒", en: "\(s)s")
    }

    var overlaySettingsOpacity: String {
        ja("背景の不透明度", en: "Background Opacity")
    }

    var overlaySettingsFontSize: String {
        ja("フォントサイズ", en: "Font Size")
    }

    var overlaySizeSmall: String {
        ja("小", en: "Small")
    }

    var overlaySizeMedium: String {
        ja("中", en: "Medium")
    }

    var overlaySizeLarge: String {
        ja("大", en: "Large")
    }

    var overlaySettingsPreview: String {
        ja("プレビュー", en: "Preview")
    }

    var overlaySettingsShowKeyCode: String {
        ja("キーコードを表示", en: "Show Key Code")
    }

    var avgIntervalFormat: String {
        ja("平均間隔: %.0f ms", en: "Avg interval: %.0f ms")
    }

    var minIntervalFormat: String {
        ja("最小間隔: %.0f ms", en: "Min interval: %.0f ms")
    }

    var exportCSVMenuItem: String {
        ja("CSV 書き出し…", en: "Export CSV…")
    }

    var exportCSVSaveButton: String {
        ja("ここに保存", en: "Save Here")
    }

    var copyDataMenuItem: String {
        ja("データをコピー", en: "Copy Data to Clipboard")
    }

    var copiedConfirmation: String {
        ja("コピーしました！", en: "Copied!")
    }

    var editPromptMenuItem: String {
        ja("AIプロンプトを編集…", en: "Edit AI Prompt…")
    }

    var editPromptTitle: String {
        ja("AIプロンプト", en: "AI Prompt")
    }

    var notificationIntervalMenuTitle: String {
        ja("通知間隔", en: "Notify Every")
    }

    func notificationIntervalLabel(_ n: Int) -> String {
        ja("\(n.formatted()) 回ごと", en: "Every \(n.formatted()) presses")
    }

    var editPromptSave: String {
        ja("保存", en: "Save")
    }

    func statsWindowHeader(since: String, today: String, total: String) -> String {
        ja(
            "\(since) から記録中  |  本日: \(today) 入力  |  合計: \(total) 入力",
            en: "Since \(since)  |  Today: \(today) inputs  |  Total: \(total) inputs"
        )
    }

    func notificationBody(key: String, count: Int) -> String {
        ja(
            "「\(key)」が \(count.formatted()) 回に達しました！",
            en: "\"\(key)\" has reached \(count.formatted()) presses!"
        )
    }

    static let dateFormatterJa: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        f.locale = Locale(identifier: "ja_JP"); return f
    }()
    static let dateFormatterEn: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        f.locale = Locale(identifier: "en_US"); return f
    }()

    /// 記録開始日を表示する文字列を返す
    func recordingSince(_ date: Date) -> String {
        let fmt = resolved == .japanese ? Self.dateFormatterJa : Self.dateFormatterEn
        let dateStr = fmt.string(from: date)
        return ja("\(dateStr) から記録中", en: "Since \(dateStr)")
    }

    // MARK: - Help popover strings

    var helpHeatmapFrequency: String {
        ja("頻度モード：各キーの合計打鍵数に応じて色付けされます。赤いキーが最もよく押されたキーです。",
           en: "Frequency mode: each key is colored by total keystroke count. Red = most pressed.")
    }

    var helpHeatmapStrain: String {
        ja("負荷モード：高負荷ビグラム（同指かつ1行以上をまたぐ連続打鍵）に含まれる頻度で各キーを色付けします。赤いキーが最も疲労しやすいキーです。",
           en: "Strain mode: each key is colored by how often it appears in high-strain bigrams — same finger, spanning ≥1 keyboard row. Red keys are frequent culprits; dark keys are rarely involved.")
    }

    var helpHeatmapStrainLegend: String {
        ja("高負荷とは、同指かつ1行以上をまたぐビグラム（例：F→R、J→U）に頻繁に登場するキーのことです。生体力学的に最も負担の大きい打鍵パターンです。",
           en: "High strain: key appears frequently in same-finger bigrams that span ≥1 row (e.g. F→R, J→U). These are the most biomechanically taxing sequences.")
    }

    var helpLearningCurve: String {
        ja(
            "3つの人間工学的指標の日次推移を示します。\n\n同指率（オレンジ）：同じ指で連続して打鍵されるペアの割合。低いほど優れています。\n\n交互打鍵率（緑）：左右の手が交互に打鍵する割合。高いほど優れています。\n\n高負荷率（赤）：1行以上をまたぐ同指ビグラムの割合。低いほど優れています。\n\n傾向が改善方向に推移している場合、打鍵習慣が人間工学的に最適化されています。",
            en: "Shows daily trends for three ergonomic metrics.\n\nSame-finger (orange): fraction of consecutive keypairs pressed by the same finger. Lower is better.\n\nAlternation (teal): fraction of keypairs that alternate between hands. Higher is better.\n\nHigh-strain (red): fraction of same-finger bigrams that span ≥1 keyboard row. Lower is better.\n\nImproving trends indicate your typing habits are becoming more ergonomic over time."
        )
    }

    var helpActivityCalendar: String {
        ja(
            "過去365日の日別打鍵数をカレンダーヒートマップで表示します。セルが濃いほど打鍵数が多い日です。",
            en: "Calendar heatmap of daily keystroke counts over the past year. Darker cells indicate more keystrokes."
        )
    }

    var helpHourlyDistribution: String {
        ja(
            "全記録セッションを通じた、時刻（0〜23時）ごとの累積打鍵数を表示します。",
            en: "Total keystrokes by hour of day across all recorded sessions."
        )
    }

    var helpLayoutComparison: String {
        ja(
            "実際の打鍵データを用いて、現行レイアウトとSFB最適化提案レイアウトを人間工学スコアで比較します。",
            en: "Compares your current layout against an SFB-optimised layout using your actual typing data."
        )
    }

    var helpBigrams: String {
        ja(
            "ビグラムとは、連続する2回の打鍵のペアです。グラフは最も頻度の高い20ペアを表示します。\n\n同指率：同じ指で連続して打鍵されるペアの割合。低いほど人間工学的に優れています。同指連打は生体力学的に最も負荷が高い動作です。\n\n交互打鍵率：左右の手が交互に打鍵するペアの割合。高いほど優れています。交互打鍵は速度と持久性を同時に高めます。",
            en: "A bigram is any two consecutive keystrokes. The chart shows your 20 most frequent pairs.\n\nSame-finger rate: how often both keys in a pair are pressed by the same finger. Lower is better — same-finger repetition is biomechanically taxing.\n\nAlternation rate: how often keystrokes alternate between left and right hands. Higher is better — alternation allows one hand to prepare while the other types."
        )
    }

    // MARK: - Helper

    private func ja(_ japanese: String, en english: String) -> String {
        resolved == .japanese ? japanese : english
    }
}
