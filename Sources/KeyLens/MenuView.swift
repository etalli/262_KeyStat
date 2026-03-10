import AppKit
import Charts
import ServiceManagement
import SwiftUI

// MARK: - MenuView

struct MenuView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @ObservedObject private var widgetStore = MenuWidgetStore.shared

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
            if isRunning {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(l.monitoringActive.dropFirst(2))
                    .font(.system(size: 13, weight: .medium))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Button(l.monitoringStopped.dropFirst(2)) {
                    appDelegate.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange)
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
        let widgets = MenuWidgetStore.shared.orderedEnabled
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(widgets) { widget in
                switch widget {
                case .recordingSince:
                    infoRow(l.recordingSince(store.startedAt))
                case .todayTotal:
                    HStack {
                        Text(String(format: l.todayFormat, store.todayCount.formatted()))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(String(format: l.totalFormat, store.totalCount.formatted()))
                            .foregroundColor(.primary)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                case .avgInterval:
                    if let avgMs = store.averageIntervalMs {
                        infoRow(String(format: l.avgIntervalFormat, avgMs))
                    }
                case .estimatedWPM:
                    if let wpm = store.estimatedWPM {
                        infoRow(String(format: l.estimatedWPMFormat, wpm))
                    }
                case .backspaceRate:
                    if let bs = store.todayBackspaceRate {
                        infoRow(String(format: l.backspaceRateFormat, bs))
                    }
                case .miniChart:
                    MiniDailyBarChart()
                case .streak:
                    let goal   = KeyCountStore.shared.dailyGoal
                    let streak = KeyCountStore.shared.currentStreak()
                    let today  = KeyCountStore.shared.todayCount
                    VStack(alignment: .leading, spacing: 0) {
                        infoRow(l.streakDisplay(streak))
                        if goal > 0 {
                            infoRow(l.goalProgress(today: today, goal: goal))
                        }
                    }
                case .shortcutEfficiency:
                    if let pct = KeyCountStore.shared.shortcutEfficiencyToday() {
                        infoRow(l.shortcutEfficiencyDisplay(pct))
                    } else {
                        infoRow(l.shortcutEfficiencyNoData)
                    }
                case .mouseDistance:
                    if let pts = MouseStore.shared.distanceToday() {
                        infoRow(l.mouseDistanceDisplay(pts))
                    } else {
                        infoRow(l.mouseDistanceNoData)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Action buttons

    private var actionRow: some View {
        let l = L10n.shared
        return VStack(alignment: .leading, spacing: 0) {
            menuRow(l.chartsMenuItem, icon: "chart.bar.xaxis") { appDelegate.showCharts() }
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
            Divider().padding(.horizontal, 14).padding(.vertical, 2)
            // 設定サブメニュー（Launch at Login・言語・通知間隔・AI Prompt・リセット）
            SettingsMenuRow()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerRow: some View {
        let l = L10n.shared
        return VStack(spacing: 0) {
            menuRow(l.aboutMenuItem)             { appDelegate.showAboutPanel() }
            menuRow(l.checkForUpdatesMenuItem)   { appDelegate.checkForUpdates() }
            menuRow(l.quit)                      { appDelegate.quit() }
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().padding(.horizontal, 0)
    }

    private func infoRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
    }

    private func menuRow(_ title: String, icon: String? = nil, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                }
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
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
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
                    .foregroundColor(isHovered ? .secondary : Color.secondary.opacity(0.3))
                    .frame(width: 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(L10n.shared.dataMenuTitle)
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

        add(l.showAllMenuItem)         { appDelegate.showAllStats() }
        menu.addItem(.separator())
        add(l.exportCSVMenuItem)       { appDelegate.exportCSV() }
        add(appDelegate.copyConfirmed ? "\(l.copyDataMenuItem) - \(l.copiedConfirmation)" : l.copyDataMenuItem) {
            appDelegate.copyDataToClipboard()
        }
        add(l.editPromptMenuItem)      { appDelegate.editAIPrompt() }
        menu.addItem(.separator())
        add(l.openSaveFolder)          { appDelegate.openSaveDir() }
        menu.addItem(.separator())
        add(l.resetMenuItem)           { appDelegate.resetCounts() }

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
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
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

        // Customize Menu
        add(l.customizeMenuMenuItem) {
            appDelegate.showMenuCustomize()
        }

        menu.addItem(.separator())

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

        // Break Reminder
        // 休憩リマインダー
        header(l.breakReminderMenuTitle)
        let brm = BreakReminderManager.shared
        add(l.breakReminderOff, checked: !brm.isEnabled) {
            brm.isEnabled = false
        }
        for mins in [15, 30, 45, 60] {
            add(l.breakReminderIntervalLabel(mins), checked: brm.isEnabled && brm.intervalMinutes == mins) {
                brm.intervalMinutes = mins
                brm.isEnabled = true
            }
        }

        menu.addItem(.separator())

        // Daily Keystroke Goal (Issue #69)
        // 1日の目標打鍵数
        header(l.dailyGoalMenuTitle)
        let ks = KeyCountStore.shared
        add(l.dailyGoalOff, checked: ks.dailyGoal == 0) { ks.dailyGoal = 0 }
        for count in [1000, 3000, 5000, 10000] {
            add(l.dailyGoalLabel(count), checked: ks.dailyGoal == count) { ks.dailyGoal = count }
        }

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

// MARK: - MiniDailyBarChart

private struct DayBar: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let isToday: Bool
}

private struct MiniDailyBarChart: View {
    @State private var days: [DayBar] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.shared.last7Days)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Count", day.count)
                )
                .foregroundStyle(day.isToday ? Color.accentColor : Color.blue.opacity(0.5))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 52)
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 4)
        .onAppear { days = loadDays() }
    }

    private func loadDays() -> [DayBar] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let symbols = cal.shortWeekdaySymbols  // ["Sun", "Mon", ..., "Sat"]
        let totals = KeyCountStore.shared.dailyTotals(last: 7)
        return totals.enumerated().compactMap { idx, pair -> DayBar? in
            guard let date = cal.date(from: cal.dateComponents([.year, .month, .day],
                                      from: fmt.date(from: pair.date) ?? Date())) else { return nil }
            let weekdayIndex = cal.component(.weekday, from: date) - 1
            let label = String(symbols[weekdayIndex].prefix(2))
            return DayBar(label: label, count: pair.count, isToday: idx == totals.count - 1)
        }
    }
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
