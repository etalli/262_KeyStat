import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    let monitor = KeyboardMonitor()
    private var permissionTimer: Timer?
    private var healthTimer: Timer?

    /// tapDisabledByTimeout コールバックから再有効化するために公開
    var eventTap: CFMachPort? { monitor.eventTap }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NotificationManager.shared

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyCounter") {
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
        KeyCounter.log("appDidBecomeActive — attempting monitor start")
        if monitor.start() {
            KeyCounter.log("appDidBecomeActive — monitoring started")
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func startMonitor() {
        if monitor.start() {
            KeyCounter.log("monitoring started")
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
            KeyCounter.log("permission retry tick — AXIsProcessTrusted: \(trusted)")
            guard trusted else { return }

            timer.invalidate()
            self.permissionTimer = nil

            if self.monitor.start() {
                KeyCounter.log("permission granted -> monitoring started")
            } else {
                // 権限は付与されたが tap 作成失敗 → 自動再起動
                KeyCounter.log("tap creation failed despite permission — auto-restarting")
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
            KeyCounter.log("health check: monitor stopped — scheduling retry")
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
        menu.addItem(.separator())

        let topKeys = store.topKeys(limit: 10)
        if topKeys.isEmpty {
            menu.addItem(NSMenuItem(title: l.noInput, action: nil, keyEquivalent: ""))
        } else {
            let rankEmoji = ["🥇", "🥈", "🥉"]
            for (i, (key, count)) in topKeys.enumerated() {
                let prefix = rankEmoji[safe: i] ?? "  "
                menu.addItem(NSMenuItem(
                    title: "\(prefix) \(key)  —  \(count.formatted())",
                    action: nil, keyEquivalent: ""
                ))
            }
        }
        menu.addItem(.separator())
    }

    private func addSettingsSection(to menu: NSMenu) {
        let l = L10n.shared

        // About
        let aboutItem = NSMenuItem(title: l.aboutMenuItem, action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Settings… サブメニュー（保存先 + 言語 + リセット）
        let settingsMenu = NSMenu()

        let openItem = NSMenuItem(title: l.openSaveFolder, action: #selector(openSaveDir), keyEquivalent: "")
        openItem.target = self
        settingsMenu.addItem(openItem)

        settingsMenu.addItem(.separator())

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

        let resetItem = NSMenuItem(title: l.resetMenuItem, action: #selector(resetCounts), keyEquivalent: "")
        resetItem.target = self
        settingsMenu.addItem(resetItem)

        let settingsItem = NSMenuItem(title: l.settingsMenuTitle, action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: l.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

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
            .appendingPathComponent("KeyCounter")
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
