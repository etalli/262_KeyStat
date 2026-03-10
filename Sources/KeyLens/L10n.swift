import Foundation
import KeyLensCore

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
        ja("● 記録中", en: "● Recording")
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

    var dataMenuTitle: String {
        ja("データ…", en: "Data…")
    }

    var settingsMenuTitle: String {
        ja("設定…", en: "Settings…")
    }

    var aboutMenuItem: String {
        ja("KeyLens について", en: "About KeyLens")
    }

    var checkForUpdatesMenuItem: String {
        ja("アップデートを確認…", en: "Check for Updates…")
    }

    var updateAvailableTitle: String {
        ja("アップデートがあります", en: "Update Available")
    }

    func updateAvailableMessage(current: String, latest: String) -> String {
        ja("現在のバージョン: \(current)\n最新バージョン: \(latest)\n\nGitHub Releases からダウンロードできます。",
           en: "Current version: \(current)\nLatest version: \(latest)\n\nDownload the latest release from GitHub.")
    }

    var updateUpToDateTitle: String {
        ja("最新バージョンです", en: "Up to Date")
    }

    func updateUpToDateMessage(version: String) -> String {
        ja("KeyLens \(version) は最新バージョンです。", en: "KeyLens \(version) is the latest version.")
    }

    var updateCheckFailedTitle: String {
        ja("確認できませんでした", en: "Check Failed")
    }

    var updateCheckFailedMessage: String {
        ja("アップデートの確認中にエラーが発生しました。ネットワーク接続を確認してください。",
           en: "Could not check for updates. Please check your network connection.")
    }

    var downloadButton: String {
        ja("ダウンロード", en: "Download")
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

    var last7Days: String {
        ja("直近7日間", en: "Last 7 Days")
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

    var overlaySettingsFontColor: String {
        ja("文字の色", en: "Font Color")
    }

    var overlaySettingsBackgroundColor: String {
        ja("背景の色", en: "Background Color")
    }

    var overlaySettingsCornerRadius: String {
        ja("角の丸み", en: "Corner Radius")
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

    var overlaySizeExtraLarge: String {
        ja("特大", en: "Extra Large")
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

    var estimatedWPMFormat: String {
        ja("速度: %.0f WPM", en: "Speed: %.0f WPM")
    }

    var backspaceRateFormat: String {
        ja("BS率: %.1f%%", en: "BS rate: %.1f%%")
    }

    var chartTitleBackspaceRate: String {
        ja("BS 率（タイピング精度）", en: "Backspace Rate (Accuracy)")
    }

    var helpBackspaceRate: String {
        ja(
            "日別の BS（Backspace）率を表示します。全打鍵数に対する Delete キーの割合（%）です。\n\n低いほど入力ミスが少なく、タイピング精度が高いことを示します。一般的なタイピストは 2〜5% 程度です。\n\n過去データも利用可能（counts.json の dailyCounts から直接算出）。",
            en: "Daily backspace rate: Delete key presses as a percentage of total keystrokes.\n\nLower is better — a lower rate means fewer typing errors. Typical typists fall in the 2–5% range.\n\nHistorical data is available immediately (derived from existing dailyCounts in counts.json)."
        )
    }

    var chartTitleTypingSpeed: String {
        ja("タイピング速度 (WPM)", en: "Typing Speed (WPM)")
    }

    var helpTypingSpeed: String {
        ja(
            "日別の推定タイピング速度（WPM）を表示します。\n\n算出方法: 1000ms 以内のキーストローク間隔のみを Welford オンライン平均で集計し、WPM = 60,000 ÷ (平均間隔ms × 5) で換算します（1ワード = 5打鍵の標準定義）。\n\n注意: このデータはこのバージョンから蓄積を開始します。過去データは表示されません。",
            en: "Daily estimated typing speed in WPM.\n\nCalculation: Only inter-keystroke intervals ≤ 1,000 ms are included in a Welford online average. WPM = 60,000 ÷ (avg interval ms × 5), using the standard definition of 1 word = 5 keystrokes.\n\nNote: Data accumulates from this version onward. No historical data is available."
        )
    }

    var exportCSVMenuItem: String {
        ja("CSV 書き出し…", en: "Export CSV…")
    }

    var exportHeatmap: String {
        ja("ヒートマップを保存", en: "Save Heatmap")
    }

    var exportSuccess: String {
        ja("保存しました", en: "Saved successfully")
    }

    var exportError: String {
        ja("保存に失敗しました", en: "Failed to save")
    }

    var exportCSVSaveButton: String {
        ja("ここに保存", en: "Save Here")
    }

    var copyDataMenuItem: String {
        ja("データをコピー", en: "Copy Data to Clipboard")
    }

    var copyHeatmap: String {
        ja("画像をコピー", en: "Copy Image")
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

    func heatmapCountTooltip(_ count: Int) -> String {
        ja("打鍵数: \(count.formatted())", en: "Count: \(count.formatted())")
    }

    func heatmapStrainTooltip(_ score: Int) -> String {
        ja("負荷スコア: \(score.formatted())", en: "Strain: \(score.formatted())")
    }

    var helpLearningCurve: String {
        ja(
            "3つの人間工学的指標の日次推移を示します。\n\n同指率（オレンジ）：同じ指で連続して打鍵されるペアの割合。低いほど優れています。\n\n交互打鍵率（緑）：左右の手が交互に打鍵する割合。高いほど優れています。\n\n高負荷率（赤）：1行以上をまたぐ同指ビグラムの割合。低いほど優れています。\n\n傾向が改善方向に推移している場合、打鍵習慣が人間工学的に最適化されています。",
            en: "Shows daily trends for three ergonomic metrics.\n\nSame-finger (orange): fraction of consecutive keypairs pressed by the same finger. Lower is better.\n\nAlternation (teal): fraction of keypairs that alternate between hands. Higher is better.\n\nHigh-strain (red): fraction of same-finger bigrams that span ≥1 keyboard row. Lower is better.\n\nImproving trends indicate your typing habits are becoming more ergonomic over time."
        )
    }

    var helpActivityCalendar: String {
        ja(
            "過去365日の日別打鍵数をカレンダーヒートマップで表示します。セルが濃いほど打鍵数が多い日です。\n\n縦軸は曜日（上から日〜土）、横軸は週（左が古く、右が最新）です。",
            en: "Calendar heatmap of daily keystroke counts over the past year. Darker cells indicate more keystrokes.\n\nRows represent days of the week (Sun at top, Sat at bottom). Columns represent weeks, with the most recent week on the right."
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

    func topAppTodayFormat(_ app: String, _ count: String) -> String {
        ja("🖥 \(app)  \(count)", en: "🖥 \(app)  \(count)")
    }

    var appsAllTime: String {
        ja("アプリ別打鍵数 — 累計", en: "Top Apps — All Time")
    }

    var appsToday: String {
        ja("アプリ別打鍵数 — 本日", en: "Top Apps — Today")
    }

    var helpApps: String {
        ja(
            "フォアグラウンドで動作していたアプリごとの打鍵数を表示します。どのアプリで最も多くタイプしているかを把握できます。",
            en: "Keystroke counts grouped by the frontmost application. Shows which apps you type in most."
        )
    }

    var devicesAllTime: String {
        ja("デバイス別打鍵数 — 累計", en: "Top Devices — All Time")
    }

    var devicesToday: String {
        ja("デバイス別打鍵数 — 本日", en: "Top Devices — Today")
    }

    var helpDevices: String {
        ja(
            "検出されたキーボードデバイス名ごとに打鍵数を表示します。内蔵キーボードと外付けキーボードでの使用傾向を比較できます。",
            en: "Keystroke counts grouped by detected keyboard device name. Useful for comparing built-in and external keyboard usage."
        )
    }

    var appErgScoreSection: String {
        ja("アプリ別エルゴノミクススコア", en: "Ergonomic Score by App")
    }

    var helpAppErgScore: String {
        ja(
            "100打鍵以上のアプリについて、実際の打鍵データから算出したエルゴノミクススコア（0〜100）を表示します。スコアが高いほど、同指率・高負荷率が低く、左右交互打鍵率が高い優れた状態です。",
            en: "Ergonomic score (0–100) computed from actual typing data for apps with ≥100 keystrokes. Higher is better: lower same-finger and high-strain rates, higher hand alternation."
        )
    }

    var appErgScoreAppHeader: String {
        ja("アプリ", en: "App")
    }

    var appErgScoreKeysHeader: String {
        ja("打鍵数", en: "Keystrokes")
    }

    var appErgScoreScoreHeader: String {
        ja("スコア", en: "Score")
    }

    var deviceErgScoreSection: String {
        ja("デバイス別エルゴノミクススコア", en: "Ergonomic Score by Device")
    }

    var helpDeviceErgScore: String {
        ja(
            "100打鍵以上のデバイスについて、実際の打鍵データから算出したエルゴノミクススコア（0〜100）を表示します。スコアが高いほど、同指率・高負荷率が低く、左右交互打鍵率が高い状態です。",
            en: "Ergonomic score (0–100) computed from actual typing data for devices with ≥100 keystrokes. Higher is better: lower same-finger and high-strain rates, higher hand alternation."
        )
    }

    var deviceErgScoreDeviceHeader: String {
        ja("デバイス", en: "Device")
    }

    var deviceErgScoreKeysHeader: String {
        ja("打鍵数", en: "Keystrokes")
    }

    var deviceErgScoreScoreHeader: String {
        ja("スコア", en: "Score")
    }

    var intelligenceSection: String {
        ja("インテリジェンス", en: "Intelligence")
    }

    var helpIntelligence: String {
        ja(
            "キー頻度パターンから推定した2つの指標を表示します。\n\n推定スタイル: よく使うキーの分布からタイピング用途を推定します。文字・スペース中心 → 執筆、記号・修飾キー多用 → 開発、短いパターン多用 → チャット。\n\n疲労リスク: 同一指で1行以上離れたキーを連続入力する「高負荷バイグラム」の割合で判定します。\n低（緑）: 2%以下 / 中（橙）: 2〜5% / 高（赤）: 5%超",
            en: "Two metrics inferred from your keystroke patterns.\n\nInferred Style: estimated from key frequency distribution. High letters/Space → Prose; high symbols/modifiers → Code; frequent short patterns → Chat.\n\nFatigue Risk: based on the high-strain bigram rate — same-finger keypairs spanning ≥1 keyboard row (e.g. F→R, J→U).\nLow (green): ≤2% / Moderate (orange): 2–5% / High (red): >5%"
        )
    }

    var inferredStyle: String {
        ja("推定スタイル", en: "Inferred Style")
    }

    var fatigueRisk: String {
        ja("疲労リスク", en: "Fatigue Risk")
    }

    func typingStyleLabel(_ style: TypingStyle) -> String {
        switch style {
        case .prose:   return ja("執筆", en: "Prose")
        case .code:    return ja("開発", en: "Code")
        case .chat:    return ja("チャット", en: "Chat")
        case .unknown: return ja("不明", en: "Unknown")
        }
    }

    func fatigueLevelLabel(_ level: FatigueLevel) -> String {
        switch level {
        case .low:      return ja("低", en: "Low")
        case .moderate: return ja("中", en: "Moderate")
        case .high:     return ja("高", en: "High")
        }
    }

    // MARK: - Menu Customization

    var customizeMenuMenuItem: String {
        ja("メニューをカスタマイズ…", en: "Customize Menu…")
    }

    var customizeMenuTitle: String {
        ja("メニュー表示のカスタマイズ", en: "Customize Menu Display")
    }

    var customizeMenuHint: String {
        ja("表示する項目を選択し、ドラッグで並び替えできます。", en: "Toggle items to show or hide, and drag to reorder.")
    }

    var customizeMenuReset: String {
        ja("デフォルトに戻す", en: "Reset to Default")
    }

    func widgetDisplayName(_ widget: MenuWidget) -> String {
        switch widget {
        case .recordingSince: return ja("記録開始日", en: "Recording Since")
        case .todayTotal:     return ja("本日 / 合計", en: "Today / Total")
        case .avgInterval:    return ja("平均打鍵間隔", en: "Avg Interval")
        case .estimatedWPM:   return ja("推定WPM", en: "Estimated WPM")
        case .backspaceRate:  return ja("BS率", en: "Backspace Rate")
        case .miniChart:      return ja("直近7日グラフ", en: "Last 7 Days Chart")
        case .streak:               return ja("ストリーク", en: "Streak")
        case .shortcutEfficiency:   return ja("ショートカット効率", en: "Shortcut Efficiency")
        case .mouseDistance:        return ja("マウス移動距離", en: "Mouse Distance")
        }
    }

    // MARK: - Break Reminder

    var breakReminderMenuTitle: String {
        ja("休憩リマインダー", en: "Break Reminder")
    }

    var breakReminderTitle: String {
        ja("☕ 休憩しましょう", en: "☕ Time for a break")
    }

    func breakReminderBody(minutes: Int) -> String {
        ja("\(minutes)分間タイピングが続いています。少し休憩しませんか？",
           en: "You've been typing for \(minutes) minutes. Consider taking a short break.")
    }

    func breakReminderIntervalLabel(_ minutes: Int) -> String {
        ja("\(minutes)分ごと", en: "Every \(minutes) min")
    }

    var breakReminderOff: String {
        ja("オフ", en: "Off")
    }

    // MARK: - Streak & Daily Goal

    /// Streak display string. n=0 shows a "no streak" placeholder.
    func streakDisplay(_ n: Int) -> String {
        n > 0
            ? ja("🔥 \(n)日連続達成中", en: "🔥 \(n)-day streak")
            : ja("🔥 ストリークなし", en: "🔥 No streak yet")
    }

    /// Today's progress toward the daily goal as a formatted string.
    func goalProgress(today: Int, goal: Int) -> String {
        let pct = goal > 0 ? min(100, today * 100 / goal) : 0
        return ja("今日: \(today.formatted()) / \(goal.formatted()) (\(pct)%)",
                  en: "Today: \(today.formatted()) / \(goal.formatted()) (\(pct)%)")
    }

    var goalReachedTitle: String {
        ja("🎉 目標達成！", en: "🎉 Daily goal reached!")
    }

    func goalReachedBody(streak: Int) -> String {
        ja("今日の打鍵目標を達成しました。\(streak)日連続達成！",
           en: "You've hit today's keystroke goal — \(streak)-day streak!")
    }

    var dailyGoalMenuTitle: String {
        ja("1日の目標打鍵数", en: "Daily Keystroke Goal")
    }

    var dailyGoalOff: String {
        ja("オフ", en: "Off")
    }

    func dailyGoalLabel(_ count: Int) -> String {
        ja("\(count.formatted())打鍵/日", en: "\(count.formatted()) keys/day")
    }

    // MARK: - Shortcut Efficiency

    /// Shortcut efficiency score display (e.g. "⌨️ Shortcut efficiency: 42%").
    func shortcutEfficiencyDisplay(_ pct: Double) -> String {
        ja("⌨️ ショートカット効率: \(Int(pct))%", en: "⌨️ Shortcut efficiency: \(Int(pct))%")
    }

    var shortcutEfficiencyNoData: String {
        ja("⌨️ ショートカットデータなし", en: "⌨️ No shortcut data yet")
    }

    // MARK: - Mouse Distance

    /// Mouse distance display string. Points are converted to km or m.
    func mouseDistanceDisplay(_ pts: Double) -> String {
        // 1 screen point ≈ 0.264 mm at 96 dpi baseline
        let meters = pts * 0.000264
        if meters >= 1000 {
            let km = meters / 1000
            return ja(String(format: "🖱 移動距離: %.2f km", km),
                      en: String(format: "🖱 Distance: %.2f km", km))
        } else {
            return ja(String(format: "🖱 移動距離: %.0f m", meters),
                      en: String(format: "🖱 Distance: %.0f m", meters))
        }
    }

    var mouseDistanceNoData: String {
        ja("🖱 移動距離データなし", en: "🖱 No mouse distance data yet")
    }

    // MARK: - Helper

    private func ja(_ japanese: String, en english: String) -> String {
        resolved == .japanese ? japanese : english
    }
}
