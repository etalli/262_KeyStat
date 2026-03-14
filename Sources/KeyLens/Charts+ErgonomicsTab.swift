import SwiftUI
import Charts
import KeyLensCore

extension ChartsView {

    var ergonomicsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Top 20 Bigrams", helpText: L10n.shared.helpBigrams, showSort: true) { bigramChart }
                chartSection("Ergonomic Learning Curve", helpText: L10n.shared.helpLearningCurve) { learningCurveChart }
                chartSection("Layout Comparison", helpText: L10n.shared.helpLayoutComparison) { layoutComparisonSection }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    var bigramChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.topBigrams.isEmpty {
                emptyState
            } else {
                let pairOrder = model.topBigrams.map(\.pair)
                let domain = sortDescending ? Array(pairOrder.reversed()) : pairOrder

                Chart(model.topBigrams) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Bigram", item.pair)
                    )
                    .foregroundStyle(Color.teal.opacity(0.8))
                    .cornerRadius(3)
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topBigrams.count * 26 + 24))
            }

            // Ergonomic metrics summary (Phase 0 data — previously computed but not shown)
            HStack(spacing: 24) {
                ergonomicMetricPair(
                    label: "Same-finger rate",
                    allTime: model.sameFingerRate,
                    today: model.todaySameFingerRate
                )
                ergonomicMetricPair(
                    label: "Hand alternation rate",
                    allTime: model.handAlternationRate,
                    today: model.todayHandAltRate
                )
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    func ergonomicMetricPair(label: String, allTime: Double?, today: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let v = allTime {
                    Text("All-time: \(Int(v * 100))%").font(.footnote.monospacedDigit())
                }
                if let v = today {
                    Text("Today: \(Int(v * 100))%").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
                if allTime == nil && today == nil {
                    Text("—").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var layoutComparisonSection: some View {
        if let cmp = model.layoutComparison {
            VStack(alignment: .leading, spacing: 12) {
                // Recommended swaps header
                // 推奨スワップのヘッダー
                let swapLabels = cmp.recommendedSwaps
                    .map { "\($0.from) ↔ \($0.to)" }
                    .joined(separator: ", ")
                Text("Recommended swaps: \(swapLabels)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Comparison Grid table
                // 比較グリッドテーブル
                Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                    // Header row
                    GridRow {
                        Text("Metric")
                            .font(.caption).bold().foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text("Current")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Proposed")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Change")
                            .font(.caption).bold().foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider().gridCellUnsizedAxes(.horizontal)

                    // Ergonomic score (higher is better)
                    comparisonRow(
                        metric: "Ergonomic score",
                        current:  String(format: "%.1f", cmp.current.ergonomicScore),
                        proposed: String(format: "%.1f", cmp.proposed.ergonomicScore),
                        delta: cmp.ergonomicScoreDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.1f", d) }
                    )

                    // Same-finger rate (lower is better)
                    comparisonRow(
                        metric: "Same-finger rate",
                        current:  pct(cmp.current.sameFingerRate),
                        proposed: pct(cmp.proposed.sameFingerRate),
                        delta: cmp.sameFingerRateDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // Hand alternation rate (higher is better)
                    comparisonRow(
                        metric: "Hand alternation",
                        current:  pct(cmp.current.handAlternationRate),
                        proposed: pct(cmp.proposed.handAlternationRate),
                        delta: cmp.handAlternationDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // High-strain rate (lower is better)
                    comparisonRow(
                        metric: "High-strain rate",
                        current:  pct(cmp.current.highStrainRate),
                        proposed: pct(cmp.proposed.highStrainRate),
                        delta: cmp.highStrainRateDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // Thumb imbalance (lower is better)
                    comparisonRow(
                        metric: "Thumb imbalance",
                        current:  String(format: "%.2f", cmp.current.thumbImbalanceRatio),
                        proposed: String(format: "%.2f", cmp.proposed.thumbImbalanceRatio),
                        delta: cmp.thumbImbalanceDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.2f", d) }
                    )

                    // Finger travel (lower is better)
                    comparisonRow(
                        metric: "Finger travel",
                        current:  String(format: "%.0f", cmp.current.estimatedTravelDistance),
                        proposed: String(format: "%.0f", cmp.proposed.estimatedTravelDistance),
                        delta: cmp.travelDistanceDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.0f", d) }
                    )
                }
                .padding(.vertical, 8)
            }
        } else if model.isLayoutComparisonLoading {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Calculating layout comparison…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            Text("Need more typing data to compute layout comparison")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        }
    }

    /// Renders one row of the comparison table with colour-coded change column.
    /// 比較テーブルの1行を色付きの変化列と共にレンダリングする。
    @ViewBuilder
    func comparisonRow(
        metric: String,
        current: String,
        proposed: String,
        delta: Double,
        positiveIsBetter: Bool,
        format: (Double) -> String
    ) -> some View {
        let threshold = 0.001
        let isImprovement = positiveIsBetter ? delta > threshold  : delta < -threshold
        let isRegression  = positiveIsBetter ? delta < -threshold : delta > threshold
        let color: Color  = isImprovement ? .green : (isRegression ? .red : .secondary)
        let arrow: String = delta > threshold ? "↑" : (delta < -threshold ? "↓" : "→")

        GridRow {
            Text(metric)
                .font(.callout)
                .gridColumnAlignment(.leading)
            Text(current)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(proposed)
                .font(.callout.monospacedDigit())
            Text("\(arrow) \(format(delta))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.vertical, 5)
    }

    /// Formats a rate as a percentage string (e.g. 0.083 → "8.3%").
    /// 比率をパーセント文字列に変換する。
    func pct(_ rate: Double) -> String { String(format: "%.1f%%", rate * 100) }

    /// Formats a rate delta as percentage points (e.g. 0.042 → "+4.2pp").
    /// 比率差をパーセントポイント表記に変換する。
    func pp(_ delta: Double) -> String { String(format: "%+.1fpp", delta * 100) }

    @ViewBuilder
    var learningCurveChart: some View {
        if model.dailyErgonomics.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(model.dailyErgonomics) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Rate", item.rate)
                    )
                    .foregroundStyle(by: .value("Metric", item.series))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Rate", item.rate)
                    )
                    .foregroundStyle(by: .value("Metric", item.series))
                }
                .chartForegroundStyleScale([
                    "Same-finger": Color.orange,
                    "Alternation": Color.teal,
                    "High-strain": Color.red
                ])
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    ForEach([("Same-finger", Color.orange), ("Alternation", Color.teal), ("High-strain", Color.red)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
