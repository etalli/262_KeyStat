// ErgonomicSnapshot.swift
// A point-in-time aggregate of all ergonomic metrics for a (layout, dataset) pair.
// レイアウトとデータセットの組み合わせに対する全エルゴノミクス指標のスナップショット。
//
// ## Design
//
// ErgonomicSnapshot is the value type that Phase 2 optimizers produce and compare.
// It is computed by `capture(bigramCounts:keyCounts:layout:)` and holds all sub-scores
// needed for Before/After layout comparison (#3) and the optimization engine (#41).
//
// Fields:
//   - ergonomicScore             [0, 100]  composite score (higher is better)
//   - sameFingerRate             [0, 1]    fraction of bigrams using the same finger
//   - highStrainRate             [0, 1]    fraction of bigrams classified as high-strain
//   - handAlternationRate        [0, 1]    fraction of bigrams that alternate hands
//   - thumbImbalanceRatio        [0, 1]    normalised left/right thumb usage imbalance
//   - thumbEfficiencyCoefficient [0, ∞]   thumb keystrokes / (total × expectedRatio)
//   - estimatedTravelDistance    [0, ∞]   total finger travel in grid units (lower = better)
//
// The snapshot is immutable; create a new instance after each key relocation simulation.
// スナップショットは不変。キー移動シミュレーションのたびに新しいインスタンスを生成する。
//
// ## Phase
// Phase 2 – Optimization Engine (Issues #3, #38–#40)

import Foundation

/// A point-in-time snapshot of all ergonomic metrics for a (layout, dataset) pair.
/// レイアウトとデータセットの組み合わせに対する全エルゴノミクス指標のスナップショット。
public struct ErgonomicSnapshot: Equatable {

    // MARK: - Composite score

    /// Unified ergonomic score in [0, 100]. Higher is better.
    /// 統合エルゴノミクススコア。0〜100、高いほど良好。
    public let ergonomicScore: Double

    // MARK: - Rate sub-metrics

    /// Fraction of bigrams where both keys are pressed by the same finger. [0, 1]
    /// Lower is better.
    /// 同指ビグラムの割合。低いほど良好。
    public let sameFingerRate: Double

    /// Fraction of bigrams classified as high-strain (same finger + ≥1 row distance). [0, 1]
    /// Lower is better.
    /// 高負荷ビグラムの割合。低いほど良好。
    public let highStrainRate: Double

    /// Fraction of bigrams where the two keys are pressed by different hands. [0, 1]
    /// Higher is better.
    /// 手交互打鍵の割合。高いほど良好。
    public let handAlternationRate: Double

    // MARK: - Thumb metrics

    /// Normalised left/right thumb usage imbalance. [0, 1]
    /// 0 = perfectly balanced, 1 = one thumb handles everything.
    /// 左右親指使用量の正規化偏り比率。0 = 完全均等、1 = 片方のみ。
    public let thumbImbalanceRatio: Double

    /// Thumb keystrokes as a multiple of the expected share. [0, ∞]
    /// 1.0 = thumbs carry expected proportion; > 1.0 = overutilised (efficient).
    /// 期待比率を基準とした親指打鍵の倍率。1.0 = 期待値通り。
    public let thumbEfficiencyCoefficient: Double

    // MARK: - Travel distance

    /// Estimated total finger travel distance (in grid units). Lower is better.
    /// 総指移動距離の推定値（グリッド単位）。低いほど良好。
    public let estimatedTravelDistance: Double

    public init(
        ergonomicScore: Double,
        sameFingerRate: Double,
        highStrainRate: Double,
        handAlternationRate: Double,
        thumbImbalanceRatio: Double,
        thumbEfficiencyCoefficient: Double,
        estimatedTravelDistance: Double
    ) {
        self.ergonomicScore             = ergonomicScore
        self.sameFingerRate             = sameFingerRate
        self.highStrainRate             = highStrainRate
        self.handAlternationRate        = handAlternationRate
        self.thumbImbalanceRatio        = thumbImbalanceRatio
        self.thumbEfficiencyCoefficient = thumbEfficiencyCoefficient
        self.estimatedTravelDistance    = estimatedTravelDistance
    }

    // MARK: - Factory

    /// Builds a fully populated snapshot by computing all metrics for the given layout and data.
    ///
    /// All rate metrics are derived by iterating `bigramCounts` with the given layout.
    /// Thumb metrics use `keyCounts` (individual keystroke frequencies, not bigrams).
    ///
    /// - Parameters:
    ///   - bigramCounts: Bigram frequency map ("k1→k2" format from KeyCountStore).
    ///   - keyCounts:    Per-key keystroke frequency map (from KeyCountStore.allKeyCounts).
    ///   - layout:       The LayoutRegistry to evaluate against.
    ///   - estimator:    Travel distance estimator (defaults to `.default`).
    /// - Returns: A fully populated snapshot. Returns baseline snapshot (score=100, all rates=0)
    ///   when bigramCounts is empty.
    ///
    /// 指定レイアウトとデータから全指標を算出してスナップショットを生成する。
    /// bigramCounts が空の場合はベースライン（score=100, 全率=0）を返す。
    public static func capture(
        bigramCounts: [String: Int],
        keyCounts:    [String: Int],
        layout:       LayoutRegistry,
        estimator:    TravelDistanceEstimator = .default
    ) -> ErgonomicSnapshot {
        guard !bigramCounts.isEmpty else {
            return ErgonomicSnapshot(
                ergonomicScore: 100.0,
                sameFingerRate: 0, highStrainRate: 0,
                handAlternationRate: 0,
                thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0,
                estimatedTravelDistance: 0
            )
        }

        // --- Bigram rate computation ------------------------------------------------
        // Iterate bigramCounts once to count same-finger, high-strain, alternating pairs.
        // bigramCounts を1回走査し、同指・高負荷・交互打鍵ペア数を集計する。
        var sfbCount   = 0
        var hsCount    = 0
        var altCount   = 0
        var totalPairs = 0
        let detector   = layout.highStrainDetector

        for (bigram, count) in bigramCounts where count > 0 {
            let parts = bigram.components(separatedBy: "→")
            guard parts.count == 2 else { continue }
            let (k1, k2) = (parts[0], parts[1])

            totalPairs += count

            guard let f1 = layout.current.finger(for: k1),
                  let f2 = layout.current.finger(for: k2) else { continue }

            let h1 = layout.hand(for: k1)
            let h2 = layout.hand(for: k2)

            if f1 == f2, h1 != nil, h1 == h2 {
                // Same finger and same hand: SFB bigram.
                // 同指・同手：SFBビグラム。
                sfbCount += count
                if detector.isHighStrain(from: k1, to: k2, layout: layout) {
                    hsCount += count
                }
            } else if h1 != nil, h2 != nil, h1 != h2 {
                // Different hands: alternating bigram.
                // 異手：交互打鍵ビグラム。
                altCount += count
            }
        }

        let total  = Double(totalPairs)
        let sfbRate = total > 0 ? Double(sfbCount) / total : 0.0
        let hsRate  = total > 0 ? Double(hsCount)  / total : 0.0
        let altRate = total > 0 ? Double(altCount)  / total : 0.0

        // --- Thumb metrics ----------------------------------------------------------
        let tiRatio = layout.thumbImbalanceDetector
            .imbalanceRatio(counts: keyCounts, layout: layout) ?? 0.0
        let teCoeff = layout.thumbEfficiencyCalculator
            .coefficient(counts: keyCounts, layout: layout) ?? 0.0

        // --- Travel distance --------------------------------------------------------
        let travel = estimator.totalTravel(counts: bigramCounts, layout: layout.current)

        // --- Composite score --------------------------------------------------------
        let score = layout.ergonomicScoreEngine.score(
            sameFingerRate:             sfbRate,
            highStrainRate:             hsRate,
            thumbImbalanceRatio:        tiRatio,
            handAlternationRate:        altRate,
            thumbEfficiencyCoefficient: teCoeff
        )

        return ErgonomicSnapshot(
            ergonomicScore:             score,
            sameFingerRate:             sfbRate,
            highStrainRate:             hsRate,
            handAlternationRate:        altRate,
            thumbImbalanceRatio:        tiRatio,
            thumbEfficiencyCoefficient: teCoeff,
            estimatedTravelDistance:    travel
        )
    }
}
