import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = KeyboardMonitor()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NotificationManager.shared

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌨️"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        startMonitor()
    }

    // MARK: - Monitor

    private func startMonitor() {
        if monitor.start() {
            print("[KeyCounter] monitoring started")
        } else {
            showPermissionAlert()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    self?.monitor.start()
                    print("[KeyCounter] permission granted -> monitoring started")
                    timer.invalidate()
                }
            }
        }
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
        let l = L10n.shared

        // ヘッダー：記録開始日
        let startedAt = KeyCountStore.shared.startedAt
        let sinceItem = NSMenuItem(title: l.recordingSince(startedAt), action: nil, keyEquivalent: "")
        sinceItem.isEnabled = false
        menu.addItem(sinceItem)

        // ヘッダー：合計カウント
        let total = KeyCountStore.shared.totalCount
        let header = NSMenuItem(
            title: String(format: l.totalFormat, total.formatted()),
            action: nil, keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // 上位10キー
        let topKeys = KeyCountStore.shared.topKeys(limit: 10)
        if topKeys.isEmpty {
            let empty = NSMenuItem(title: l.noInput, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let rankEmoji = ["🥇", "🥈", "🥉"]
            for (i, (key, count)) in topKeys.enumerated() {
                let prefix = rankEmoji[safe: i] ?? "  "
                let item = NSMenuItem(
                    title: "\(prefix) \(key)  —  \(count.formatted())",
                    action: nil, keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // 言語サブメニュー
        let langMenu = NSMenu()
        for lang in Language.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(changeLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang
            item.state = (l.language == lang) ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: l.languageMenuTitle, action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())

        // 保存先を開く
        let openItem = NSMenuItem(title: l.openSaveFolder, action: #selector(openSaveDir), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

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
