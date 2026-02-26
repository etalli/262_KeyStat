import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    let monitor = KeyboardMonitor()
    private var permissionTimer: Timer?
    private var healthTimer: Timer?

    /// tapDisabledByTimeout コールバックから再有効化するために公開
    var eventTap: CFMachPort? { monitor.eventTap }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NotificationManager.shared
        _ = KeystrokeOverlayController.shared

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyLens") {
            image.isTemplate = true
            statusItem.button?.image = image
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        startMonitor()
        setupHealthCheck()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Monitor

    @objc private func appDidBecomeActive() {
        guard !monitor.isRunning else { return }
        KeyLens.log("appDidBecomeActive — attempting monitor start")
        if monitor.start() {
            KeyLens.log("appDidBecomeActive — monitoring started")
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func startMonitor() {
        if monitor.start() {
            KeyLens.log("monitoring started")
        } else {
            // 現在のバイナリをアクセシビリティリストに登録し、設定画面を開く
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            schedulePermissionRetry()
        }
    }

    /// アクセシビリティ権限が付与されるまで 3 秒ごとにリトライする
    private func schedulePermissionRetry() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            KeyLens.log("permission retry tick — AXIsProcessTrusted: \(trusted)")
            guard trusted else { return }

            timer.invalidate()
            self.permissionTimer = nil

            if self.monitor.start() {
                KeyLens.log("permission granted -> monitoring started")
            } else {
                // 権限は付与されたが tap 作成失敗 → 自動再起動
                KeyLens.log("tap creation failed despite permission — auto-restarting")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.restartApp()
                }
            }
        }
    }

    /// 5 秒ごとに監視状態を確認し、停止していれば自動でリトライを開始する
    private func setupHealthCheck() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.monitor.isRunning, self.permissionTimer == nil else { return }
            KeyLens.log("health check: monitor stopped — scheduling retry")
            self.schedulePermissionRetry()
        }
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        addStatusSection(to: menu)
        addStatsSection(to: menu)
        addSettingsSection(to: menu)
    }

    // MARK: - Menu sections

    private func addStatusSection(to menu: NSMenu) {
        let l = L10n.shared
        let isRunning = monitor.isRunning
        let dotColor: NSColor = isRunning ? .systemGreen : .systemRed
        let fullString = isRunning ? l.monitoringActive : l.monitoringStopped
        let statusAttr = NSMutableAttributedString(
            string: fullString,
            attributes: [.foregroundColor: NSColor.labelColor]
        )
        if let dotRange = fullString.range(of: "●") {
            let nsRange = NSRange(dotRange, in: fullString)
            statusAttr.addAttribute(.foregroundColor, value: dotColor, range: nsRange)
        }
        let item = NSMenuItem(
            title: "",
            action: isRunning ? nil : #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        item.attributedTitle = statusAttr
        item.target = self
        menu.addItem(item)
        menu.addItem(.separator())
    }

    private func addStatsSection(to menu: NSMenu) {
        let l = L10n.shared
        let store = KeyCountStore.shared

        menu.addItem(NSMenuItem(title: l.recordingSince(store.startedAt), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(
            title: String(format: l.todayFormat, store.todayCount.formatted()),
            action: nil, keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: String(format: l.totalFormat, store.totalCount.formatted()),
            action: nil, keyEquivalent: ""
        ))
        if let avgMs = store.averageIntervalMs {
            menu.addItem(NSMenuItem(
                title: String(format: l.avgIntervalFormat, avgMs),
                action: nil, keyEquivalent: ""
            ))
        }
        if let minMs = store.todayMinIntervalMs {
            menu.addItem(NSMenuItem(
                title: String(format: l.minIntervalFormat, minMs),
                action: nil, keyEquivalent: ""
            ))
        }
        menu.addItem(.separator())

        let topKeys = store.topKeys(limit: 10)
        if topKeys.isEmpty {
            menu.addItem(NSMenuItem(title: l.noInput, action: nil, keyEquivalent: ""))
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 150)]
            let rankEmoji = ["🥇", "🥈", "🥉"]
            for (i, (key, count)) in topKeys.enumerated() {
                let prefix = rankEmoji[safe: i] ?? "   "
                let attrTitle = NSAttributedString(
                    string: "\(prefix) \(key)\t\(count.formatted())",
                    attributes: [.paragraphStyle: paragraphStyle]
                )
                let item = NSMenuItem()
                item.attributedTitle = attrTitle
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let showAllItem = NSMenuItem(title: l.showAllMenuItem, action: #selector(showAllStats), keyEquivalent: "")
        showAllItem.target = self
        menu.addItem(showAllItem)

        let chartsItem = NSMenuItem(title: l.chartsMenuItem, action: #selector(showCharts), keyEquivalent: "")
        chartsItem.target = self
        menu.addItem(chartsItem)

        let overlayItem = NSMenuItem(title: l.overlayMenuItem, action: #selector(toggleOverlay), keyEquivalent: "")
        overlayItem.target = self
        overlayItem.state = KeystrokeOverlayController.shared.isEnabled ? .on : .off
        menu.addItem(overlayItem)
        menu.addItem(.separator())
    }

    private func addSettingsSection(to menu: NSMenu) {
        let l = L10n.shared

        // Settings… サブメニュー
        let settingsMenu = NSMenu()

        // ログイン時起動
        let launchAtLoginItem = NSMenuItem(title: l.launchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        settingsMenu.addItem(launchAtLoginItem)

        settingsMenu.addItem(.separator())

        // 言語
        let langMenu = NSMenu()
        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            item.state = (l.language == lang) ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: l.languageMenuTitle, action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        settingsMenu.addItem(langItem)

        settingsMenu.addItem(.separator())

        // データ操作
        let openItem = NSMenuItem(title: l.openSaveFolder, action: #selector(openSaveDir), keyEquivalent: "")
        openItem.target = self
        settingsMenu.addItem(openItem)

        let csvItem = NSMenuItem(title: l.exportCSVMenuItem, action: #selector(exportCSV), keyEquivalent: "")
        csvItem.target = self
        settingsMenu.addItem(csvItem)

        let copyDataItem = NSMenuItem(title: l.copyDataMenuItem, action: #selector(copyDataToClipboard), keyEquivalent: "")
        copyDataItem.target = self
        settingsMenu.addItem(copyDataItem)

        let editPromptItem = NSMenuItem(title: l.editPromptMenuItem, action: #selector(editAIPrompt), keyEquivalent: "")
        editPromptItem.target = self
        settingsMenu.addItem(editPromptItem)

        settingsMenu.addItem(.separator())

        // 破壊的操作
        let resetItem = NSMenuItem(title: l.resetMenuItem, action: #selector(resetCounts), keyEquivalent: "")
        resetItem.target = self
        settingsMenu.addItem(resetItem)

        let settingsItem = NSMenuItem(title: l.settingsMenuTitle, action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: l.aboutMenuItem, action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: l.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func showAllStats() {
        StatsWindowController.shared.showWindow()
    }

    @objc private func showCharts() {
        ChartsWindowController.shared.showWindow()
    }

    @objc private func toggleOverlay() {
        KeystrokeOverlayController.shared.isEnabled.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            KeyLens.log("LaunchAtLogin toggle failed: \(error)")
        }
    }

    @objc private func exportCSV() {
        let store = KeyCountStore.shared
        let summary = store.exportSummaryCSV()
        let daily   = store.exportDailyCSV()

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let tag = dateFmt.string(from: Date())

        let panel = NSOpenPanel()
        panel.title = L10n.shared.exportCSVMenuItem
        panel.prompt = L10n.shared.exportCSVSaveButton
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dir = panel.url else { return }
            let summaryURL = dir.appendingPathComponent("KeyLens_summary_\(tag).csv")
            let dailyURL   = dir.appendingPathComponent("KeyLens_daily_\(tag).csv")
            try? summary.write(to: summaryURL, atomically: true, encoding: .utf8)
            try? daily.write(to: dailyURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(dir)
        }
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? Language else { return }
        L10n.shared.language = lang
    }

    @objc private func resetCounts() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l.resetAlertTitle
        alert.informativeText = l.resetAlertMessage
        alert.addButton(withTitle: l.resetConfirmButton)
        alert.addButton(withTitle: l.cancel)
        alert.buttons[0].hasDestructiveAction = true

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            KeyCountStore.shared.reset()
        }
    }

    @objc private func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private static let aiPromptDefaults: [Language: String] = [
        .english: """
You are a keyboard layout optimization analyst.

Using the provided key input log:

1. Compute:
   - Total key frequency
   - Bigram and trigram frequency
   - Same-finger repetition rate
   - Hand alternation rate
   - Temporal change of frequency (learning/adaptation trend)

2. Identify:
   - Keys that cause high ergonomic load
   - Keys that would benefit from relocation to thumbs
   - Frequently combined key pairs suitable for thumb modifiers

3. Assume:
   - Split keyboard
   - 4 thumb keys per hand
   - Minimize finger travel and same-finger repetition

Output:
- Data summary table
- Optimization reasoning
- Recommended thumb assignments
- Expected ergonomic improvement estimate
""",
        .japanese: """
あなたはキーボードレイアウト最適化の専門家です。

以下のキー入力ログを分析してください：

1. 計算してください：
   - キーごとの使用頻度
   - バイグラム・トライグラム頻度
   - 同指連続入力率
   - 左右交互打鍵率
   - 頻度の時系列変化（学習・適応トレンド）

2. 特定してください：
   - 人間工学的負荷が高いキー
   - 親指キーに移動すると効果的なキー
   - 親指モディファイアに適したキーの組み合わせ

3. 前提条件：
   - 分割キーボード
   - 片手4つの親指キー
   - 指の移動距離と同指連続入力を最小化

出力：
- データサマリー表
- 最適化の根拠
- 推奨親指キー割り当て
- 期待される人間工学的改善効果の推定
"""
    ]

    private static func aiPromptKey(for lang: Language) -> String {
        "aiPrompt_\(lang.rawValue)"
    }

    private static func currentPrompt() -> String {
        let lang = L10n.shared.resolved
        let key = aiPromptKey(for: lang)
        return UserDefaults.standard.string(forKey: key)
            ?? aiPromptDefaults[lang]
            ?? aiPromptDefaults[.english]!
    }

    @objc private func copyDataToClipboard() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens/counts.json")
        guard let data = try? Data(contentsOf: url),
              let json = String(data: data, encoding: .utf8) else { return }
        let content = "\(Self.currentPrompt())\n\n\(json)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    @objc private func editAIPrompt() {
        let l = L10n.shared
        let current = Self.currentPrompt()

        let alert = NSAlert()
        alert.messageText = l.editPromptTitle
        alert.addButton(withTitle: l.editPromptSave)
        alert.addButton(withTitle: l.cancel)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.string = current
        scrollView.documentView = textView

        alert.accessoryView = scrollView

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let lang = L10n.shared.resolved
            UserDefaults.standard.set(textView.string, forKey: Self.aiPromptKey(for: lang))
        }
    }

    @objc private func openSaveDir() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        NSWorkspace.shared.open(dir)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Array helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
