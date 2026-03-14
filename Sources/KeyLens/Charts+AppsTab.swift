import SwiftUI
import Charts
import KeyLensCore

extension ChartsView {

    var appsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.appsAllTime, helpText: L10n.shared.helpApps, showSort: true) { topAppsChart }
                chartSection(L10n.shared.appsToday, showSort: true) { todayTopAppsChart }
                if !model.appErgScores.isEmpty {
                    chartSection(L10n.shared.appErgScoreSection, helpText: L10n.shared.helpAppErgScore) {
                        appErgScoreTable
                    }
                }
                chartSection(L10n.shared.devicesAllTime, helpText: L10n.shared.helpDevices, showSort: true) { topDevicesChart }
                chartSection(L10n.shared.devicesToday, showSort: true) { todayTopDevicesChart }
                if !model.deviceErgScores.isEmpty {
                    chartSection(L10n.shared.deviceErgScoreSection, helpText: L10n.shared.helpDeviceErgScore) {
                        deviceErgScoreTable
                    }
                }
            }
            .padding(24)
        }
    }

    var appErgScoreTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text(L10n.shared.appErgScoreAppHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.shared.appErgScoreKeysHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                Text(L10n.shared.appErgScoreScoreHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            ForEach(model.appErgScores) { entry in
                HStack {
                    Text(entry.app)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(entry.keystrokes.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 4) {
                        // Score bar (fills proportionally from 0–100)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor(entry.score).opacity(0.25))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(scoreColor(entry.score))
                                        .frame(width: geo.size.width * entry.score / 100)
                                }
                        }
                        .frame(width: 44, height: 8)
                        Text(String(format: "%.0f", entry.score))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(scoreColor(entry.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
    }

    var deviceErgScoreTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.shared.deviceErgScoreDeviceHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.shared.deviceErgScoreKeysHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                Text(L10n.shared.deviceErgScoreScoreHeader)
                    .font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)

            ForEach(model.deviceErgScores) { entry in
                HStack {
                    Text(entry.device)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(entry.keystrokes.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 4) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor(entry.score).opacity(0.25))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(scoreColor(entry.score))
                                        .frame(width: geo.size.width * entry.score / 100)
                                }
                        }
                        .frame(width: 44, height: 8)
                        Text(String(format: "%.0f", entry.score))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(scoreColor(entry.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
    }

    func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    @ViewBuilder
    var topAppsChart: some View {
        if model.topApps.isEmpty {
            emptyState
        } else {
            let appOrder = model.topApps.map(\.app)
            let domain = sortDescending ? Array(appOrder.reversed()) : appOrder

            Chart(model.topApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.topApps.count * 28 + 24))
        }
    }

    @ViewBuilder
    var todayTopAppsChart: some View {
        if model.todayTopApps.isEmpty {
            emptyState
        } else {
            let appOrder = model.todayTopApps.map(\.app)
            let domain = sortDescending ? Array(appOrder.reversed()) : appOrder

            Chart(model.todayTopApps) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("App", item.app)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.todayTopApps.count * 28 + 24))
        }
    }

    @ViewBuilder
    var topDevicesChart: some View {
        if model.topDevices.isEmpty {
            emptyState
        } else {
            let deviceOrder = model.topDevices.map(\.device)
            let domain = sortDescending ? Array(deviceOrder.reversed()) : deviceOrder

            Chart(model.topDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.topDevices.count * 28 + 24))
        }
    }

    @ViewBuilder
    var todayTopDevicesChart: some View {
        if model.todayTopDevices.isEmpty {
            emptyState
        } else {
            let deviceOrder = model.todayTopDevices.map(\.device)
            let domain = sortDescending ? Array(deviceOrder.reversed()) : deviceOrder

            Chart(model.todayTopDevices) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Device", item.device)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.todayTopDevices.count * 28 + 24))
        }
    }
}
