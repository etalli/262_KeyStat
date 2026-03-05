import XCTest
@testable import KeyLensCore

// Tests for ErgonomicScoreEngine and ErgonomicScoreWeights (Issue #29 — Phase 1).
//
// ## What is being tested
//
// 1. Edge cases — score formula with extreme input values
//    - No data (all zeros)       → 100.0 (baseline, no penalty, no bonus)
//    - All same-finger (sfb=1.0) → 100 - 0.30×100 = 70.0
//    - All high-strain (hs=1.0)  → 100 - 0.25×100 = 75.0
//    - Max thumb imbalance        → 100 - 0.15×100 = 85.0
//    - Perfect alternation        → 100 + 0.20×100 = 120 → clamped to 100.0
//    - Max thumb efficiency (2.0) → 100 + 0.10×100 = 110 → clamped to 100.0
//    - Worst-case all penalties   → 100 - 70 = 30.0
//    - Clamping at zero           → never goes below 0
//
// 2. Thumb efficiency normalisation
//    - coeff = thumbEfficiencyMax → sub-score 100 (full bonus)
//    - coeff > thumbEfficiencyMax → capped at sub-score 100
//    - thumbEfficiencyMax = 0     → sub-score 0 (guard: divide-by-zero)
//
// 3. Configurable weights
//    - Custom weight table produces expected result
//
// 4. Default values
//    - ErgonomicScoreWeights.default matches Issue #29 spec
//    - ErgonomicScoreEngine.default uses .default weights and teMax=2.0
//
// 5. LayoutRegistry integration
//    - shared registry exposes ergonomicScoreEngine
//    - engine can be replaced and restored
//
// 6. End-to-end integration
//    - Realistic bigram scenario: known rates → verify expected score
//    - Perfect typist scenario: no penalties + some rewards → 100 (clamped)
//
// スコア式エッジケース、正規化、設定可能な重み、LayoutRegistry統合をテストする。

// MARK: - Accuracy helper

private let accuracy = 1e-9

final class ErgonomicScoreEngineTests: XCTestCase {

    let engine = ErgonomicScoreEngine.default

    // MARK: - 1. Edge cases

    func testNoData_allZeros_returns100() {
        // When no keystrokes recorded, all rates are 0 → baseline score.
        // データゼロ時は全率 = 0 → スコア = 100。
        let s = engine.score(
            sameFingerRate: 0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }

    func testAllSameFinger_reducesScoreBy30() {
        // sfbRate = 1.0 → penalty = 0.30 × 100 = 30 → score = 70.
        let s = engine.score(
            sameFingerRate: 1.0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 70.0, accuracy: accuracy)
    }

    func testAllHighStrain_reducesScoreBy25() {
        // hsRate = 1.0 → penalty = 0.25 × 100 = 25 → score = 75.
        let s = engine.score(
            sameFingerRate: 0, highStrainRate: 1.0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 75.0, accuracy: accuracy)
    }

    func testMaxThumbImbalance_reducesScoreBy15() {
        // tiRatio = 1.0 → penalty = 0.15 × 100 = 15 → score = 85.
        let s = engine.score(
            sameFingerRate: 0, highStrainRate: 0,
            thumbImbalanceRatio: 1.0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 85.0, accuracy: accuracy)
    }

    func testPerfectAlternation_clampedTo100() {
        // altRate = 1.0 → bonus = 0.20 × 100 = 20 → raw 120 → clamped to 100.
        let s = engine.score(
            sameFingerRate: 0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 1.0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }

    func testMaxThumbEfficiency_clampedTo100() {
        // teCoeff = 2.0 (= thumbEfficiencyMax) → sub-score 100 → bonus = 0.10×100 = 10 → raw 110 → clamped to 100.
        let s = engine.score(
            sameFingerRate: 0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 2.0
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }

    func testWorstCase_allNegative_equals30() {
        // sfb=1 + hs=1 + ti=1, no rewards → 100 - 30 - 25 - 15 = 30.
        let s = engine.score(
            sameFingerRate: 1.0, highStrainRate: 1.0,
            thumbImbalanceRatio: 1.0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 30.0, accuracy: accuracy)
    }

    func testClamp_neverBelowZero() {
        // Even beyond worst case, score must be ≥ 0.
        // Custom weights that produce a very negative raw value.
        let heavy = ErgonomicScoreEngine(
            weights: ErgonomicScoreWeights(
                sameFingerPenalty: 2.0,
                highStrainPenalty: 2.0,
                thumbImbalancePenalty: 2.0,
                alternationReward: 0,
                thumbEfficiencyBonus: 0
            ),
            thumbEfficiencyMax: 2.0
        )
        let s = heavy.score(
            sameFingerRate: 1.0, highStrainRate: 1.0,
            thumbImbalanceRatio: 1.0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertGreaterThanOrEqual(s, 0.0)
    }

    // MARK: - 2. Thumb efficiency normalisation

    func testThumbEfficiency_atMax_fullBonus() {
        // coeff = teMax → te100 = 100 → bonus = 0.10 × 100 = 10 → raw = 110 → 100.
        let s = engine.score(
            sameFingerRate: 0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: engine.thumbEfficiencyMax
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }

    func testThumbEfficiency_aboveMax_capped() {
        // coeff > teMax must produce the same sub-score as coeff = teMax (capped at 100).
        let atMax  = engine.score(sameFingerRate: 0, highStrainRate: 0, thumbImbalanceRatio: 0, handAlternationRate: 0, thumbEfficiencyCoefficient: 2.0)
        let beyond = engine.score(sameFingerRate: 0, highStrainRate: 0, thumbImbalanceRatio: 0, handAlternationRate: 0, thumbEfficiencyCoefficient: 99.0)
        XCTAssertEqual(atMax, beyond, accuracy: accuracy)
    }

    func testThumbEfficiency_halfMax_halfBonus() {
        // coeff = teMax/2 = 1.0 → te100 = 50 → bonus = 0.10 × 50 = 5 → raw = 105 → 100 (clamped).
        // Use non-zero penalties to see the partial bonus effect below 100.
        // sfb=0.50 → -15, coeff=1.0 → +5 → raw = 90.
        let s = engine.score(
            sameFingerRate: 0.50, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 1.0
        )
        // 100 - 0.30×50 + 0.10×50 = 100 - 15 + 5 = 90.
        XCTAssertEqual(s, 90.0, accuracy: accuracy)
    }

    func testThumbEfficiency_zeroMax_producesZeroSubScore() {
        // thumbEfficiencyMax = 0: guard prevents divide-by-zero → te sub-score = 0.
        let zeroMax = ErgonomicScoreEngine(weights: .default, thumbEfficiencyMax: 0)
        let s = zeroMax.score(
            sameFingerRate: 0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 1.5
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)  // no TE bonus → baseline 100.
    }

    // MARK: - 3. Configurable weights

    func testCustomWeights_equalWeightsOnAllComponents() {
        // All weights = 0.10; sfb=1.0 → -10; alt=1.0 → +10 → raw = 100 → 100 (clamped).
        let flat = ErgonomicScoreEngine(
            weights: ErgonomicScoreWeights(
                sameFingerPenalty: 0.10,
                highStrainPenalty: 0.10,
                thumbImbalancePenalty: 0.10,
                alternationReward: 0.10,
                thumbEfficiencyBonus: 0.10
            ),
            thumbEfficiencyMax: 2.0
        )
        // sfb=1 → -10; alt=1 → +10; rest=0 → raw = 100.
        let s = flat.score(
            sameFingerRate: 1.0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 1.0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }

    func testCustomWeights_zeroAllWeights_alwaysReturns100() {
        // All weights = 0 → no penalties or bonuses → always 100.
        let zero = ErgonomicScoreEngine(
            weights: ErgonomicScoreWeights(
                sameFingerPenalty: 0, highStrainPenalty: 0,
                thumbImbalancePenalty: 0, alternationReward: 0,
                thumbEfficiencyBonus: 0
            ),
            thumbEfficiencyMax: 2.0
        )
        let s = zero.score(
            sameFingerRate: 1.0, highStrainRate: 1.0,
            thumbImbalanceRatio: 1.0, handAlternationRate: 1.0,
            thumbEfficiencyCoefficient: 1.0
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }

    // MARK: - 4. Default values

    func testDefaultWeights_matchSpec() {
        let w = ErgonomicScoreWeights.default
        XCTAssertEqual(w.sameFingerPenalty,     0.30, accuracy: accuracy)
        XCTAssertEqual(w.highStrainPenalty,     0.25, accuracy: accuracy)
        XCTAssertEqual(w.thumbImbalancePenalty, 0.15, accuracy: accuracy)
        XCTAssertEqual(w.alternationReward,     0.20, accuracy: accuracy)
        XCTAssertEqual(w.thumbEfficiencyBonus,  0.10, accuracy: accuracy)
    }

    func testDefaultEngine_usesDefaultWeightsAndTeMax2() {
        XCTAssertEqual(ErgonomicScoreEngine.default.weights, ErgonomicScoreWeights.default)
        XCTAssertEqual(ErgonomicScoreEngine.default.thumbEfficiencyMax, 2.0, accuracy: accuracy)
    }

    func testEquatable_sameParameters() {
        let e1 = ErgonomicScoreEngine(weights: .default, thumbEfficiencyMax: 2.0)
        let e2 = ErgonomicScoreEngine(weights: .default, thumbEfficiencyMax: 2.0)
        XCTAssertEqual(e1, e2)
    }

    func testEquatable_differentTeMax() {
        let e1 = ErgonomicScoreEngine(weights: .default, thumbEfficiencyMax: 2.0)
        let e2 = ErgonomicScoreEngine(weights: .default, thumbEfficiencyMax: 3.0)
        XCTAssertNotEqual(e1, e2)
    }

    // MARK: - 5. LayoutRegistry integration

    func testLayoutRegistry_hasDefaultEngine() {
        XCTAssertEqual(LayoutRegistry.shared.ergonomicScoreEngine, ErgonomicScoreEngine.default)
    }

    func testLayoutRegistry_engineReplacement() {
        let custom = ErgonomicScoreEngine(
            weights: ErgonomicScoreWeights(
                sameFingerPenalty: 0.50, highStrainPenalty: 0,
                thumbImbalancePenalty: 0, alternationReward: 0,
                thumbEfficiencyBonus: 0
            ),
            thumbEfficiencyMax: 2.0
        )
        LayoutRegistry.shared.ergonomicScoreEngine = custom
        defer { LayoutRegistry.shared.ergonomicScoreEngine = .default }

        XCTAssertEqual(LayoutRegistry.shared.ergonomicScoreEngine, custom)
        // sfb=1.0 with custom weight 0.50 → 100 - 50 = 50.
        let s = LayoutRegistry.shared.ergonomicScoreEngine.score(
            sameFingerRate: 1.0, highStrainRate: 0,
            thumbImbalanceRatio: 0, handAlternationRate: 0,
            thumbEfficiencyCoefficient: 0
        )
        XCTAssertEqual(s, 50.0, accuracy: accuracy)
    }

    // MARK: - 6. End-to-end integration

    func testIntegration_realisticScenario() {
        // Simulates typical measured rates for an average QWERTY typist:
        //   sfbRate = 0.06  (6% — typical for QWERTY English text)
        //   hsRate  = 0.03  (3% — plausible high-strain fraction)
        //   tiRatio = 0.10  (10% thumb imbalance)
        //   altRate = 0.52  (52% hand alternation — slightly above 50%)
        //   teCoeff = 1.10  (10% above Space-key baseline)
        //
        // Expected (with default weights):
        //   100 - 0.30×6 - 0.25×3 - 0.15×10 + 0.20×52 + 0.10×(1.10/2.0)×100
        //   = 100 - 1.80 - 0.75 - 1.50 + 10.40 + 5.50
        //   = 111.85 → clamped to 100.0
        //
        // QWERTY 平均的タイパーの実測値に近い入力でスコアを検証する。
        let s = engine.score(
            sameFingerRate:             0.06,
            highStrainRate:             0.03,
            thumbImbalanceRatio:        0.10,
            handAlternationRate:        0.52,
            thumbEfficiencyCoefficient: 1.10
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)  // rewards exceed penalties → clamped
    }

    func testIntegration_heavySameFingerTypist() {
        // A typist with severe SFB and no alternation benefit:
        //   sfbRate = 0.30  (30% — extreme same-finger usage)
        //   hsRate  = 0.15  (15% — many high-strain sequences)
        //   tiRatio = 0.40  (40% thumb imbalance)
        //   altRate = 0.10  (10% alternation — mostly same-hand)
        //   teCoeff = 0.50  (thumbs at half expected usage)
        //
        // Expected:
        //   100 - 0.30×30 - 0.25×15 - 0.15×40 + 0.20×10 + 0.10×(0.50/2.0)×100
        //   = 100 - 9.0 - 3.75 - 6.0 + 2.0 + 2.5
        //   = 85.75
        let s = engine.score(
            sameFingerRate:             0.30,
            highStrainRate:             0.15,
            thumbImbalanceRatio:        0.40,
            handAlternationRate:        0.10,
            thumbEfficiencyCoefficient: 0.50
        )
        XCTAssertEqual(s, 85.75, accuracy: accuracy)
    }

    func testIntegration_perfectErgonomicTypist() {
        // No SFB, no high-strain, perfectly balanced thumbs, full alternation, max thumb efficiency.
        // → score = 100 (penalties = 0, rewards push above 100 → clamped).
        let s = engine.score(
            sameFingerRate:             0,
            highStrainRate:             0,
            thumbImbalanceRatio:        0,
            handAlternationRate:        1.0,
            thumbEfficiencyCoefficient: 2.0
        )
        XCTAssertEqual(s, 100.0, accuracy: accuracy)
    }
}
