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
        if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyStat") {
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
        KeyStat.log("appDidBecomeActive — attempting monitor start")
        if monitor.start() {
            KeyStat.log("appDidBecomeActive — monitoring started")
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func startMonitor() {
        if monitor.start() {
            KeyStat.log("monitoring started")
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
            KeyStat.log("permission retry tick — AXIsProcessTrusted: \(trusted)")
            guard trusted else { return }

            timer.invalidate()
            self.permissionTimer = nil

            if self.monitor.start() {
                KeyStat.log("permission granted -> monitoring started")
            } else {
                // 権限は付与されたが tap 作成失敗 → 自動再起動
                KeyStat.log("tap creation failed despite permission — auto-restarting")
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
            KeyStat.log("health check: monitor stopped — scheduling retry")
            self.schedulePermissionRetry()
        }
    }

    private func showRestartAlert() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l.restartTitle
        alert.informativeText = l.restartMessage
        alert.addButton(withTitle: l.restartNow)
        alert.addButton(withTitle: l.later)

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            restartApp()
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

    private func showPermissionAlert() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l.accessibilityTitle
        alert.informativeText = l.accessibilityMessage
        alert.addButton(withTitle: l.openSystemSettings)
        alert.addButton(withTitle: l.later)

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
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
        let statusAttr = NSAttributedString(
            string: isRunning ? l.monitoringActive : l.monitoringStopped,
            attributes: [.foregroundColor: isRunning ? NSColor.systemGreen : NSColor.systemRed]
        )
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
                title: String(format: "⌨ Avg interval: %.0f ms", avgMs),
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
            KeyStat.log("LaunchAtLogin toggle failed: \(error)")
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
            let summaryURL = dir.appendingPathComponent("KeyStat_summary_\(tag).csv")
            let dailyURL   = dir.appendingPathComponent("KeyStat_daily_\(tag).csv")
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

    @objc private func openSaveDir() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyStat")
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
