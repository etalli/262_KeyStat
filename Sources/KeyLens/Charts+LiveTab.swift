import SwiftUI
import Charts

extension ChartsView {

    var liveTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartSection(L10n.shared.chartTitleRecentIKI, helpText: L10n.shared.helpRecentIKI) { recentIKIChart }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
                .padding(.leading, 24)
                .padding(.bottom, 24)
                .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.refreshLiveData()
            liveTimer?.invalidate()
            liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                model.refreshLiveData()
            }
        }
        .onDisappear {
            liveTimer?.invalidate()
            liveTimer = nil
        }
    }

    /// Bar chart of IKI (ms) for the last 20 keystrokes. Bars are color-coded by speed.
    /// 直近20打鍵のIKI棒グラフ。速度に応じて色分けする。
    @ViewBuilder
    var recentIKIChart: some View {
        let entries = model.recentIKIEntries
        if entries.isEmpty {
            VStack(spacing: 6) {
                emptyState
                Text("Type with this window open to see live timing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: recentIKIChartWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(entries) { item in
                    let bar = BarMark(
                        x: .value("Key", item.id),
                        y: .value("IKI (ms)", item.chartIKI)
                    )
                    .foregroundStyle(item.isAnchor  ? Color.gray.opacity(0.4)   :
                                     item.isFast    ? Color.green.opacity(0.8)  :
                                     item.isSlow    ? Color.red.opacity(0.8)    :
                                                      Color.orange.opacity(0.75))
                    .cornerRadius(2)
                    if item.isSlow {
                        // Capped at 300ms — show actual value so it's distinct from a genuine 300ms bar.
                        bar.annotation(position: .top, spacing: 2) {
                            Text("\(Int(item.iki))ms")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Color.red)
                        }
                    } else if ikichartShowKeyLabels {
                        bar.annotation(position: .top, spacing: 2) {
                            Text(item.key)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        bar
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisGridLine() }
                }
                .chartYScale(domain: 0...recentIKIChartMaxDisplay)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 100, 200, 300]) { value in
                        AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0)ms") }
                        AxisGridLine()
                    }
                }
                .frame(height: recentIKIPlotHeight)
                HStack(spacing: 16) {
                    Label("Fast (<150ms)", systemImage: "circle.fill").foregroundStyle(.green)
                    Label("Medium",        systemImage: "circle.fill").foregroundStyle(.orange)
                    Label("Slow (>400ms)", systemImage: "circle.fill").foregroundStyle(.red)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(width: recentIKIChartWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
