import SwiftUI
import KeyLensCore

extension ChartsView {

    var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.intelligenceSection, helpText: L10n.shared.helpIntelligence) { intelligenceGroup }
                chartSection("Weekly Report") { weeklyDeltaSection }
                chartSection("Activity Calendar", helpText: L10n.shared.helpActivityCalendar) { activityCalendarChart }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    var intelligenceGroup: some View {
        HStack(spacing: 40) {
            intelligenceCard(
                title: L10n.shared.inferredStyle,
                value: L10n.shared.typingStyleLabel(KeyCountStore.shared.currentTypingStyle),
                icon: styleIcon(KeyCountStore.shared.currentTypingStyle),
                color: theme.accentColor
            )

            intelligenceCard(
                title: L10n.shared.fatigueRisk,
                value: L10n.shared.fatigueLevelLabel(KeyCountStore.shared.currentFatigueLevel),
                icon: fatigueIcon(KeyCountStore.shared.currentFatigueLevel),
                color: fatigueColor(KeyCountStore.shared.currentFatigueLevel)
            )
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    func intelligenceCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }

    func styleIcon(_ style: TypingStyle) -> String {
        switch style {
        case .prose:   return "doc.text"
        case .code:    return "terminal"
        case .chat:    return "message"
        case .unknown: return "questionmark.circle"
        }
    }

    func fatigueIcon(_ level: FatigueLevel) -> String {
        switch level {
        case .low:      return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high:     return "exclamationmark.octagon.fill"
        }
    }

    func fatigueColor(_ level: FatigueLevel) -> Color {
        switch level {
        case .low:      return .green
        case .moderate: return .orange
        case .high:     return .red
        }
    }

    @ViewBuilder
    var weeklyDeltaSection: some View {
        if model.weeklyDeltas.isEmpty {
            Text("Need at least two weeks of data")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                    GridRow {
                        Text("Metric")
                            .font(.caption).bold().foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text("This week")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Last week")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Δ")
                            .font(.caption).bold().foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider()
                        .gridCellUnsizedAxes(.horizontal)

                    ForEach(model.weeklyDeltas) { row in
                        GridRow {
                            Text(row.metric)
                                .font(.callout)
                                .gridColumnAlignment(.leading)
                            Text(weeklyFormat(row.thisWeek, metric: row.metric))
                                .font(.callout.monospacedDigit())
                            Text(weeklyFormat(row.lastWeek, metric: row.metric))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                            deltaLabel(row)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    func weeklyFormat(_ value: Double, metric: String) -> String {
        if metric == "Keystrokes" {
            return Int(value).formatted()
        } else {
            return "\(Int(value * 100))%"
        }
    }

    @ViewBuilder
    func deltaLabel(_ row: WeeklyDeltaRow) -> some View {
        let threshold = row.metric == "Keystrokes" ? 0.01 : 0.005
        let isImprovement = row.lowerIsBetter ? row.delta < -threshold : row.delta > threshold
        let isRegression  = row.lowerIsBetter ? row.delta > threshold  : row.delta < -threshold
        let color: Color  = isImprovement ? .green : (isRegression ? .red : .secondary)

        let absStr: String = {
            if row.metric == "Keystrokes" {
                return abs(Int(row.delta)).formatted()
            } else {
                return "\(Int(abs(row.delta) * 100))pp"
            }
        }()
        let arrow = row.delta > threshold ? "↑" : (row.delta < -threshold ? "↓" : "→")

        Text("\(arrow) \(absStr)")
            .font(.callout.monospacedDigit())
            .foregroundStyle(color)
    }

    /// Calendar heatmap showing daily keystroke counts for the past 365 days.
    /// 過去365日の日別打鍵数をカレンダーヒートマップで表示する。
    @ViewBuilder
    var activityCalendarChart: some View {
        if model.dailyTotals.isEmpty {
            emptyState
        } else {
            ActivityCalendarView(dailyTotals: model.dailyTotals)
        }
    }
}
