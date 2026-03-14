import SwiftUI
import Charts

extension ChartsView {

    var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("⌘ Keyboard Shortcuts", showSort: true) { shortcutsChart }
                chartSection("All Keyboard Combos", showSort: true) { allCombosChart }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    var shortcutsChart: some View {
        if model.shortcuts.isEmpty {
            emptyState
        } else {
            let keyOrder = model.shortcuts.map(\.key)
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder

            Chart(model.shortcuts) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Shortcut", item.key)
                )
                .foregroundStyle(shortcutColor(item.key))
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.shortcuts.count * 26 + 24))
        }
    }

    func shortcutColor(_ key: String) -> Color {
        switch key {
        case "⌘c": return .green
        case "⌘v": return .blue
        case "⌘x": return .orange
        case "⌘z": return .purple
        default:    return .teal
        }
    }

    @ViewBuilder
    var allCombosChart: some View {
        if model.allCombos.isEmpty {
            emptyState
        } else {
            let keyOrder = model.allCombos.map(\.key)
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder

            VStack(alignment: .leading, spacing: 6) {
                Chart(model.allCombos) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Combo", item.key)
                    )
                    .foregroundStyle(comboColor(item.key))
                    .cornerRadius(3)
                    .annotation(position: .trailing, spacing: 4) {
                        Text(item.count.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.allCombos.count * 26 + 24))

                // 凡例
                HStack(spacing: 14) {
                    ForEach([("⌘", Color.teal), ("⌃", Color.orange), ("⌥", Color.purple), ("⇧", Color.green), ("Multi", Color.pink)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    func comboColor(_ key: String) -> Color {
        let modifiers = ["⌘", "⌃", "⌥", "⇧"]
        let found = modifiers.filter { key.hasPrefix($0) || key.contains($0) }
        if found.count > 1 { return .pink }
        switch found.first {
        case "⌘": return .teal
        case "⌃": return .orange
        case "⌥": return .purple
        case "⇧": return .green
        default:   return .gray
        }
    }
}
