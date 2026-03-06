import AppKit
import ServiceManagement

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
        objectWillChange.send()
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
        objectWillChange.send()
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
        objectWillChange.send()
    }

    func setMilestoneInterval(_ interval: Int) {
        KeyCountStore.milestoneInterval = interval
        objectWillChange.send()
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
        AboutWindowController.shared.show()
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
              var json = String(data: data, encoding: .utf8) else { return }
        
        // Inject current intelligence insights into the JSON (simplified)
        let style = KeyCountStore.shared.currentTypingStyle.rawValue
        let fatigue = KeyCountStore.shared.currentFatigueLevel.rawValue
        let insights = """
          "intelligence": {
            "typingStyle": "\(style)",
            "fatigueLevel": "\(fatigue)"
          },
        """
        if let range = json.range(of: "{") {
            json.insert(contentsOf: insights, at: range.upperBound)
        }

        let content = "\(AIPromptStore.shared.currentPrompt)\n\n\(json)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        copyConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyConfirmed = false
        }
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
