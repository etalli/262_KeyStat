import AppKit
import ServiceManagement
import SwiftUI

// MARK: - MenuView

struct MenuView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            divider
            statsSection
            divider
            actionRow
            divider
            settingsSection
            divider
            footerRow
        }
        .frame(width: 280)
        .padding(.vertical, 6)
    }

    // MARK: - Status

    private var statusRow: some View {
        let l = L10n.shared
        let isRunning = appDelegate.isMonitoring
        return HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            if isRunning {
                Text(l.monitoringActive.dropFirst(2))
                    .font(.system(size: 13, weight: .medium))
            } else {
                Button(l.monitoringStopped.dropFirst(2)) {
                    appDelegate.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Stats

    private var statsSection: some View {
        let l = L10n.shared
        let store = KeyCountStore.shared
        let rankEmoji = ["🥇", "🥈", "🥉"]
        let topKeys = store.topKeys(limit: 3)

        return VStack(alignment: .leading, spacing: 0) {
            infoRow(l.recordingSince(store.startedAt))

            // Today + Total を1行に
            HStack {
                Text(String(format: l.todayFormat, store.todayCount.formatted()))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: l.totalFormat, store.totalCount.formatted()))
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 4)

            // Avg interval
            if let avgMs = store.averageIntervalMs {
                infoRow(String(format: l.avgIntervalFormat, avgMs))
            }

            // Top 3 バッジ
            if !topKeys.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(topKeys.enumerated()), id: \.offset) { i, entry in
                        HStack(spacing: 3) {
                            Text(rankEmoji[i]).font(.system(size: 11))
                            Text(displayKey(entry.key)).font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            } else {
                infoRow(l.noInput)
            }

            // 本日のトップアプリ
            if let topApp = store.todayTopApps(limit: 1).first {
                infoRow(l.topAppTodayFormat(topApp.app, topApp.count.formatted()))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Action buttons

    private var actionRow: some View {
        let l = L10n.shared
        return VStack(alignment: .leading, spacing: 0) {
            menuRow(l.showAllMenuItem) { appDelegate.showAllStats() }
            menuRow(l.chartsMenuItem)  { appDelegate.showCharts() }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        return VStack(alignment: .leading, spacing: 0) {
            // オーバーレイ（トグル + 設定ギア 1行）
            OverlayRow()
            Divider().padding(.horizontal, 14).padding(.vertical, 2)
            // データ操作サブメニュー
            DataMenuRow()
            // 設定サブメニュー（Launch at Login・言語・通知間隔・リセット）
            SettingsMenuRow()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerRow: some View {
        let l = L10n.shared
        return VStack(spacing: 0) {
            menuRow(l.aboutMenuItem) { appDelegate.showAboutPanel() }
            menuRow(l.quit)          { appDelegate.quit() }
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().padding(.horizontal, 0)
    }

    private func displayKey(_ key: String) -> String {
        key.hasPrefix("🖱") ? "Mouse \(key.dropFirst())" : key
    }

    private func infoRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
    }

    private func menuRow(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(destructive ? .red : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }
}

// MARK: - OverlayRow (toggle + gear in one row)

private struct OverlayRow: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var isHovered = false

    var body: some View {
        let l = L10n.shared
        let isEnabled = KeystrokeOverlayController.shared.isEnabled
        HStack(spacing: 0) {
            // トグル部分（テキストのみ）
            Button(action: { appDelegate.toggleOverlay() }) {
                HStack {
                    Text(l.overlayMenuItem)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.leading, 14)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // ギアボタン：チェックマークの左、ホバー時のみ表示
            Button(action: { appDelegate.showOverlaySettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .secondary : .clear)
                    .frame(width: 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isHovered)

            // チェックマーク（最右端・固定位置・他の toggleRow と揃える）
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isEnabled ? .accentColor : .clear)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture { appDelegate.toggleOverlay() }
        }
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - DataMenuRow (submenu)

private struct DataMenuRow: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var isHovered = false

    var body: some View {
        Button(action: showMenu) {
            HStack {
                Text("Data...")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }

    private func showMenu() {
        let l = L10n.shared
        let menu = NSMenu()
        var held: [NSMenuItemAction] = []

        func add(_ title: String, _ block: @escaping () -> Void) {
            let a = NSMenuItemAction(block)
            held.append(a)
            let item = NSMenuItem(title: title, action: #selector(NSMenuItemAction.invoke), keyEquivalent: "")
            item.target = a
            menu.addItem(item)
        }

        add(l.exportCSVMenuItem)       { appDelegate.exportCSV() }
        add(l.editPromptMenuItem)      { appDelegate.editAIPrompt() }
        add(appDelegate.copyConfirmed ? "\(l.copyDataMenuItem) - \(l.copiedConfirmation)" : l.copyDataMenuItem) {
            appDelegate.copyDataToClipboard()
        }
        menu.addItem(.separator())
        add(l.openSaveFolder)          { appDelegate.openSaveDir() }

        guard let event = NSApp.currentEvent else { return }
        withExtendedLifetime(held) {
            NSMenu.popUpContextMenu(menu, with: event, for: event.window?.contentView ?? NSView())
        }
    }
}

// MARK: - SettingsMenuRow (submenu: Language / Notify Every / Reset)

private struct SettingsMenuRow: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        Button(action: showMenu) {
            HStack {
                Text(L10n.shared.settingsMenuTitle)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }

    private func showMenu() {
        let l = L10n.shared
        let menu = NSMenu()
        var held: [NSMenuItemAction] = []

        func add(_ title: String, checked: Bool = false, _ block: @escaping () -> Void) {
            let a = NSMenuItemAction(block)
            held.append(a)
            let item = NSMenuItem(title: title, action: #selector(NSMenuItemAction.invoke), keyEquivalent: "")
            item.target = a
            item.state = checked ? .on : .off
            menu.addItem(item)
        }

        func header(_ title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        // Launch at Login
        add(l.launchAtLogin, checked: SMAppService.mainApp.status == .enabled) {
            appDelegate.toggleLaunchAtLogin()
        }

        menu.addItem(.separator())

        // Language
        header(l.languageMenuTitle)
        let currentLang = l.language
        for lang in Language.allCases {
            add(lang.displayName, checked: currentLang == lang) {
                appDelegate.changeLanguage(to: lang)
            }
        }

        menu.addItem(.separator())

        // Notify Every
        header(l.notificationIntervalMenuTitle)
        let currentInterval = KeyCountStore.milestoneInterval
        for interval in [100, 500, 1000, 5000, 10000] {
            add(l.notificationIntervalLabel(interval), checked: currentInterval == interval) {
                appDelegate.setMilestoneInterval(interval)
            }
        }

        menu.addItem(.separator())

        // Reset
        add(l.resetMenuItem) { appDelegate.resetCounts() }

        guard let event = NSApp.currentEvent else { return }
        withExtendedLifetime(held) {
            NSMenu.popUpContextMenu(menu, with: event, for: event.window?.contentView ?? NSView())
        }
    }
}

// MARK: - NSMenuItemAction helper

private final class NSMenuItemAction: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    @objc func invoke() { block() }
}

// MARK: - HoverRowStyle

private struct HoverRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
