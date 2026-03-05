// ErgonomicScoreEngine.swift
// Combines all Phase 1 ergonomic metrics into a single comparable score [0, 100].
// Phase 1 のエルゴノミクス指標を 0〜100 の統合スコアに集約する。
//
// ## Formula
//
//   score = 100
//     - weights.sameFingerPenalty    × (sameFingerRate   × 100)
//     - weights.highStrainPenalty    × (highStrainRate   × 100)
//     - weights.thumbImbalancePenalty× (thumbImbalanceRatio × 100)
//     + weights.alternationReward    × (handAlternationRate × 100)
//     + weights.thumbEfficiencyBonus × (min(teCoeff / teMax, 1.0) × 100)
//
// All sub-scores are normalised to [0, 100] before weighting.
// The final value is clamped to [0, 100].
//
// ## Baseline behaviour
// When no keystroke data is available, all rates are 0 and the score is 100.0
// (base) — no penalties applied, no bonuses earned.
//
// データがない場合、全率 = 0 → スコア = 100.0（ペナルティなし・ボーナスなし）。
//
// ## Alternation sub-score
// Uses handAlternationRate (fraction of bigrams that alternate hands), NOT the
// cumulative alternationRewardScore. The cumulative value is unbounded and not
// suitable for direct normalisation.
//
// 交互打鍵サブスコアは handAlternationRate（率）を使用。
// 累積 alternationRewardScore は非有界のため除外。
//
// ## Phase
// Phase 1 – Unified Ergonomic Model — completion milestone (Issue #29)

import Foundation

// MARK: - ErgonomicScoreWeights

/// Configurable weights for each component of the ergonomic score formula.
///
/// Weights for penalty components (subtracted) and reward components (added).
/// All weights must be non-negative. There is no constraint that they sum to 1.0.
///
/// | Component             | Direction | Default |
/// |-----------------------|-----------|---------|
/// | sameFingerPenalty     | negative  | 0.30    |
/// | highStrainPenalty     | negative  | 0.25    |
/// | thumbImbalancePenalty | negative  | 0.15    |
/// | alternationReward     | positive  | 0.20    |
/// | thumbEfficiencyBonus  | positive  | 0.10    |
///
/// エルゴノミクススコアの各成分に対する設定可能な重みテーブル。
public struct ErgonomicScoreWeights: Equatable {

    /// Weight for same-finger bigram penalty (Issue #24). Direction: negative.
    /// 同指ビグラムペナルティの重み。方向：減点。
    public let sameFingerPenalty: Double

    /// Weight for high-strain sequence penalty (Issue #28). Direction: negative.
    /// 高負荷シーケンスペナルティの重み。方向：減点。
    public let highStrainPenalty: Double

    /// Weight for thumb imbalance penalty (Issue #26). Direction: negative.
    /// 親指偏りペナルティの重み。方向：減点。
    public let thumbImbalancePenalty: Double

    /// Weight for hand alternation reward (Issue #25). Direction: positive.
    /// 手交互打鍵報酬の重み。方向：加点。
    public let alternationReward: Double

    /// Weight for thumb efficiency bonus (Issue #27). Direction: positive.
    /// 親指効率ボーナスの重み。方向：加点。
    public let thumbEfficiencyBonus: Double

    public init(
        sameFingerPenalty: Double,
        highStrainPenalty: Double,
        thumbImbalancePenalty: Double,
        alternationReward: Double,
        thumbEfficiencyBonus: Double
    ) {
        self.sameFingerPenalty     = sameFingerPenalty
        self.highStrainPenalty     = highStrainPenalty
        self.thumbImbalancePenalty = thumbImbalancePenalty
        self.alternationReward     = alternationReward
        self.thumbEfficiencyBonus  = thumbEfficiencyBonus
    }

    // MARK: - Default

    /// Default weights as specified in Issue #29.
    ///
    /// Penalty total: 0.30 + 0.25 + 0.15 = 0.70 (max deduction: 70 pts)
    /// Reward total:  0.20 + 0.10 = 0.30 (max addition: 30 pts)
    ///
    /// Issue #29 仕様のデフォルト重みテーブル。
    public static let `default` = ErgonomicScoreWeights(
        sameFingerPenalty:     0.30,
        highStrainPenalty:     0.25,
        thumbImbalancePenalty: 0.15,
        alternationReward:     0.20,
        thumbEfficiencyBonus:  0.10
    )
}

// MARK: - ErgonomicScoreEngine

/// Combines Phase 1 ergonomic metrics into a single score in [0, 100].
///
/// Usage:
/// ```swift
/// let score = ErgonomicScoreEngine.default.score(
///     sameFingerRate:            0.05,   // 5% SFB rate
///     highStrainRate:            0.02,   // 2% high-strain rate
///     thumbImbalanceRatio:       0.10,   // 10% imbalance
///     handAlternationRate:       0.55,   // 55% alternation
///     thumbEfficiencyCoefficient: 1.2   // 20% above baseline
/// )
/// // → 100 - 0.30×5 - 0.25×2 - 0.15×10 + 0.20×55 + 0.10×60 = 100 - 1.5 - 0.5 - 1.5 + 11.0 + 6.0 = 113.5 → 100.0 (clamped)
/// ```
///
/// Phase 1 の全エルゴノミクス指標を 0〜100 の統合スコアに集約する。
public struct ErgonomicScoreEngine: Equatable {

    /// Component weights for the score formula.
    /// スコア式の各成分重み。
    public let weights: ErgonomicScoreWeights

    /// Maximum thumb efficiency coefficient used for normalisation to [0, 100].
    /// A coefficient of `thumbEfficiencyMax` maps to sub-score 100.
    /// Coefficients above this are capped at 100.
    ///
    /// Default 2.0: thumbs handling twice the expected share → maximum efficiency bonus.
    ///
    /// 親指効率係数の正規化上限。この値が sub-score 100 に対応する（上限でキャップ）。
    public let thumbEfficiencyMax: Double

    public init(weights: ErgonomicScoreWeights, thumbEfficiencyMax: Double) {
        self.weights            = weights
        self.thumbEfficiencyMax = thumbEfficiencyMax
    }

    // MARK: - Default

    /// Default engine: Issue #29 weights, thumbEfficiencyMax = 2.0.
    /// デフォルト設定：Issue #29 重みテーブル、親指効率上限 2.0。
    public static let `default` = ErgonomicScoreEngine(
        weights: .default,
        thumbEfficiencyMax: 2.0
    )

    // MARK: - Score computation

    /// Computes the unified ergonomic score from normalised sub-metrics.
    ///
    /// All rate parameters must be in [0, 1].
    /// `thumbEfficiencyCoefficient` is unconstrained but capped at `thumbEfficiencyMax` for scoring.
    ///
    /// - Parameters:
    ///   - sameFingerRate:             Fraction of bigrams using the same finger. [0, 1]
    ///   - highStrainRate:             Fraction of bigrams classified as high-strain. [0, 1]
    ///   - thumbImbalanceRatio:        Normalised left/right thumb usage imbalance. [0, 1]
    ///   - handAlternationRate:        Fraction of bigrams that alternate hands. [0, 1]
    ///   - thumbEfficiencyCoefficient: Thumb keystrokes / (total × expectedRatio). [0, ∞]
    /// - Returns: Ergonomic score clamped to [0, 100]. Higher is better.
    ///
    /// 5つの正規化済みサブ指標からエルゴノミクススコアを算出する。高いほど良好。
    public func score(
        sameFingerRate:             Double,
        highStrainRate:             Double,
        thumbImbalanceRatio:        Double,
        handAlternationRate:        Double,
        thumbEfficiencyCoefficient: Double
    ) -> Double {
        // Normalise each sub-metric to [0, 100].
        // 各サブ指標を [0, 100] に正規化する。
        let sfb100 = sameFingerRate  * 100
        let hs100  = highStrainRate  * 100
        let ti100  = thumbImbalanceRatio * 100
        let alt100 = handAlternationRate * 100
        let te100  = thumbEfficiencyMax > 0
            ? min(thumbEfficiencyCoefficient / thumbEfficiencyMax, 1.0) * 100
            : 0.0

        let raw = 100.0
            - weights.sameFingerPenalty     * sfb100
            - weights.highStrainPenalty     * hs100
            - weights.thumbImbalancePenalty * ti100
            + weights.alternationReward     * alt100
            + weights.thumbEfficiencyBonus  * te100

        return max(0.0, min(100.0, raw))
    }
}
