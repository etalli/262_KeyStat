import SwiftUI
import Charts
import KeyLensCore

extension ChartsView {

    var keyboardTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Keyboard Heatmap") { KeyboardHeatmapView(counts: model.keyCounts) }
                chartSection("Top 20 Keys — All Time", showSort: true) { topKeysChart }
                chartSection("Key Categories") { categoryChart }
                chartSection("Top 10 Keys per Day", showSort: true) { perDayChart }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    var topKeysChart: some View {
        if model.topKeys.isEmpty {
            emptyState
        } else {
            let keyOrder = model.topKeys.map(\.key)
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder

            VStack(alignment: .leading, spacing: 6) {
                Chart(model.topKeys) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Key", item.key)
                    )
                    .foregroundStyle(KeyType.classify(item.key).color)
                    .cornerRadius(3)
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topKeys.count * 26 + 24))

                // カラーレジェンド
                let presentTypes = Set(model.topKeys.map { KeyType.classify($0.key) })
                HStack(spacing: 14) {
                    ForEach(KeyType.allCases, id: \.self) { type in
                        if presentTypes.contains(type) {
                            HStack(spacing: 4) {
                                Circle().fill(type.color).frame(width: 8, height: 8)
                                Text(type.label).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var categoryChart: some View {
        if model.categories.isEmpty {
            emptyState
        } else if #available(macOS 14.0, *) {
            donutChart
        } else {
            stackedBarCategories
        }
    }

    @available(macOS 14.0, *)
    var donutChart: some View {
        HStack(alignment: .center, spacing: 28) {
            Chart(model.categories) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.52),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(item.type.color)
            }
            .chartLegend(.hidden)
            .frame(width: 180, height: 180)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.categories) { item in
                    HStack(spacing: 8) {
                        Circle().fill(item.type.color).frame(width: 10, height: 10)
                        Text(item.type.label).font(.callout)
                        Spacer()
                        Text(item.count.formatted())
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 160)
                }
            }
        }
    }

    // macOS 13 フォールバック: 横積みバー + レジェンド
    var stackedBarCategories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(model.categories) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Category", "")
                )
                .foregroundStyle(item.type.color)
            }
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .frame(height: 40)

            HStack(spacing: 14) {
                ForEach(model.categories) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.type.color).frame(width: 8, height: 8)
                        Text("\(item.type.label) \(item.count.formatted())")
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var perDayChart: some View {
        if model.perDayKeys.isEmpty {
            emptyState
        } else {
            let keyOrder = model.perDayKeys
                .reduce(into: [String: Int]()) { $0[$1.key, default: 0] += $1.count }
                .sorted { $0.value > $1.value }
                .map(\.key)
            let domain = sortDescending ? keyOrder : Array(keyOrder.reversed())

            Chart(model.perDayKeys) { item in
                BarMark(
                    x: .value("Key", item.key),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(by: .value("Date", item.date))
                .position(by: .value("Date", item.date))
                .cornerRadius(3)
            }
            .chartXScale(domain: domain)
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
        }
    }
}
