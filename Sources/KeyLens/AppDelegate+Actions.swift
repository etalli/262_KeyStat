import AppKit
import ServiceManagement

// MARK: - NSTextViewDelegate

extension AppDelegate: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        NSApp.stopModal()
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
        } else if let str = link as? String, let url = URL(string: str) {
            NSWorkspace.shared.open(url)
        }
        return true
    }
}

// MARK: - Actions

extension AppDelegate {

    func showAllStats() {
        StatsWindowController.shared.showWindow()
    }

    func showCharts() {
        ChartsWindowController.shared.showWindow()
    }

    func toggleOverlay() {
        KeystrokeOverlayController.shared.isEnabled.toggle()
    }

    func showOverlaySettings() {
        OverlaySettingsController.shared.showWindow()
    }

    func toggleLaunchAtLogin() {
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

    func exportCSV() {
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

    func changeLanguage(to lang: Language) {
        L10n.shared.language = lang
    }

    func setMilestoneInterval(_ interval: Int) {
        KeyCountStore.milestoneInterval = interval
    }

    func resetCounts() {
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

    func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        let l = L10n.shared
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let urlString = "https://github.com/etalli/262_KeyLens"
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrString = NSMutableAttributedString(string: urlString)
        attrString.addAttributes([
            .link: urlString,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: para
        ], range: NSRange(location: 0, length: attrString.length))

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 280, height: 18))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textStorage?.setAttributedString(attrString)
        textView.delegate = self

        let alert = NSAlert()
        alert.messageText = "KeyLens \(version)"
        alert.informativeText = ""
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            alert.icon = icon
        }
        alert.accessoryView = textView
        alert.addButton(withTitle: l.close)
        alert.runModal()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func copyDataToClipboard() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens/counts.json")
        guard let data = try? Data(contentsOf: url),
              let json = String(data: data, encoding: .utf8) else { return }
        let content = "\(AIPromptStore.shared.currentPrompt)\n\n\(json)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    func editAIPrompt() {
        let l = L10n.shared
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
        textView.string = AIPromptStore.shared.currentPrompt
        scrollView.documentView = textView

        alert.accessoryView = scrollView

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            AIPromptStore.shared.save(textView.string)
        }
    }

    func openSaveDir() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        NSWorkspace.shared.open(dir)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
