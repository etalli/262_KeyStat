import AppKit
import ServiceManagement

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {

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

        let overlayItem = NSMenuItem(title: l.overlayMenuItem, action: #selector(toggleOverlay), keyEquivalent: "")
        overlayItem.target = self
        overlayItem.state = KeystrokeOverlayController.shared.isEnabled ? .on : .off
        settingsMenu.addItem(overlayItem)

        let overlaySettingsItem = NSMenuItem(title: l.overlaySettingsMenuItem, action: #selector(showOverlaySettings), keyEquivalent: "")
        overlaySettingsItem.target = self
        settingsMenu.addItem(overlaySettingsItem)

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

        // 通知間隔
        let intervalMenu = NSMenu()
        for interval in [100, 500, 1000, 5000, 10000] {
            let item = NSMenuItem(title: l.notificationIntervalLabel(interval),
                                  action: #selector(setMilestoneInterval(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.tag = interval
            item.state = (KeyCountStore.milestoneInterval == interval) ? .on : .off
            intervalMenu.addItem(item)
        }
        let intervalItem = NSMenuItem(title: l.notificationIntervalMenuTitle, action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        settingsMenu.addItem(intervalItem)

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
}

// MARK: - Array helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
