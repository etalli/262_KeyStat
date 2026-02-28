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
        let topKeys = store.topKeys(limit: 10)

        return VStack(alignment: .leading, spacing: 0) {
            infoRow(l.recordingSince(store.startedAt))
            infoRow(String(format: l.todayFormat, store.todayCount.formatted()))
            infoRow(String(format: l.totalFormat, store.totalCount.formatted()))
            if let avgMs = store.averageIntervalMs {
                infoRow(String(format: l.avgIntervalFormat, avgMs))
            }
            if let minMs = store.todayMinIntervalMs {
                infoRow(String(format: l.minIntervalFormat, minMs))
            }

            if !topKeys.isEmpty {
                Divider().padding(.horizontal, 14).padding(.vertical, 4)
                ForEach(Array(topKeys.enumerated()), id: \.offset) { i, entry in
                    HStack {
                        Text(i < rankEmoji.count ? rankEmoji[i] : "   ")
                            .frame(width: 24, alignment: .leading)
                        Text(displayKey(entry.key))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(entry.count.formatted())
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            } else {
                infoRow(l.noInput)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Action buttons

    private var actionRow: some View {
        let l = L10n.shared
        return HStack(spacing: 8) {
            actionButton(l.showAllMenuItem) { appDelegate.showAllStats() }
            actionButton(l.chartsMenuItem)  { appDelegate.showCharts() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        let l = L10n.shared
        return VStack(alignment: .leading, spacing: 0) {
            // ログイン時起動
            toggleRow(l.launchAtLogin, isOn: SMAppService.mainApp.status == .enabled) {
                appDelegate.toggleLaunchAtLogin()
            }
            // オーバーレイ
            toggleRow(l.overlayMenuItem, isOn: KeystrokeOverlayController.shared.isEnabled) {
                appDelegate.toggleOverlay()
            }
            menuRow(l.overlaySettingsMenuItem) { appDelegate.showOverlaySettings() }
            menuRow(l.openSaveFolder)          { appDelegate.openSaveDir() }
            menuRow(l.exportCSVMenuItem)       { appDelegate.exportCSV() }
            menuRow(l.copyDataMenuItem)        { appDelegate.copyDataToClipboard() }
            menuRow(l.editPromptMenuItem)      { appDelegate.editAIPrompt() }

            Divider().padding(.horizontal, 14).padding(.vertical, 2)

            // 言語
            languageSection

            Divider().padding(.horizontal, 14).padding(.vertical, 2)

            // 通知間隔
            milestoneSection

            Divider().padding(.horizontal, 14).padding(.vertical, 2)

            // リセット
            menuRow(l.resetMenuItem) { appDelegate.resetCounts() }
        }
        .padding(.vertical, 4)
    }

    private var languageSection: some View {
        let l = L10n.shared
        return HStack(spacing: 0) {
            Text(l.languageMenuTitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.leading, 14)
            Spacer()
            ForEach(Language.allCases, id: \.self) { lang in
                LanguageChipButton(lang: lang, isSelected: l.language == lang) {
                    appDelegate.changeLanguage(to: lang)
                }
            }
            .padding(.trailing, 10)
        }
        .padding(.vertical, 5)
    }

    private var milestoneSection: some View {
        let l = L10n.shared
        return VStack(alignment: .leading, spacing: 4) {
            Text(l.notificationIntervalMenuTitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
            HStack(spacing: 4) {
                ForEach([100, 500, 1000, 5000, 10000], id: \.self) { interval in
                    MilestoneChipButton(interval: interval,
                                        isSelected: KeyCountStore.milestoneInterval == interval) {
                        appDelegate.setMilestoneInterval(interval)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 5)
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

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(maxWidth: .infinity)
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

// MARK: - Chip Buttons

private struct LanguageChipButton: View {
    let lang: Language
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(lang.displayName, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.15)
                          : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
            )
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

private struct MilestoneChipButton: View {
    let interval: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(interval >= 1000 ? "\(interval / 1000)k" : "\(interval)")
                .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.2)
                      : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
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
