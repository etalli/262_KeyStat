import XCTest
@testable import KeyLensCore

// Tests for TravelDistanceEstimator and ErgonomicSnapshot (Issue #40).
//
// ## Key positions used (ANSILayout, unit grid)
//
//   Row 2 (home row):  a(2,1)  s(2,2)  d(2,3)  f(2,4)  g(2,5)  h(2,6)  j(2,7)  k(2,8)  l(2,9)
//   Row 1 (top row):   q(1,1)  w(1,2)  e(1,3)  r(1,4)  t(1,5)
//   Row 0 (num row):   1(0,2)  2(0,3)  3(0,4)  4(0,5)  5(0,6)
//
// ## Distance examples (columnWidth = rowHeight = 1.0)
//
//   f→g : col diff 1, row diff 0  → 1.0            (adjacent)
//   f→j : col diff 3, row diff 0  → 3.0            (same row, wider)
//   a→5 : col diff 5, row diff 2  → √29 ≈ 5.385    (cross-row)
//   a→l : col diff 8, row diff 0  → 8.0            (same row, far)
//
// ## Test coverage
//
// 1. distance — zero for same key
// 2. distance — adjacent key (col diff 1)
// 3. distance — same-row vs cross-row ordering  (adjacent < same-row < cross-row)
// 4. distance — configurable columnWidth / rowHeight scaling
// 5. totalTravel — empty counts returns 0
// 6. totalTravel — single bigram: count × distance
// 7. totalTravel — multiple bigrams accumulate correctly
// 8. totalTravel — unknown key is silently skipped
// 9. totalTravel — zero-count bigram is skipped
// 10. projectedTravel — swap brings distant keys together, reducing travel
// 11. projectedTravel — identity relocation equals totalTravel
// 12. ErgonomicSnapshot.capture — matches manual totalTravel call

final class TravelDistanceEstimatorTests: XCTestCase {

    private let layout    = ANSILayout()
    private let estimator = TravelDistanceEstimator.default

    // MARK: - 1. distance: same key → 0

    func test_distance_sameKey_isZero() {
        let pos = layout.position(for: "f")!
        XCTAssertEqual(estimator.distance(from: pos, to: pos), 0.0)
    }

    // MARK: - 2. distance: adjacent key

    func test_distance_adjacent_isOne() {
        // f (row 2, col 4) → g (row 2, col 5): col diff = 1, row diff = 0 → 1.0
        let posF = layout.position(for: "f")!
        let posG = layout.position(for: "g")!
        XCTAssertEqual(estimator.distance(from: posF, to: posG), 1.0, accuracy: 1e-10)
    }

    // MARK: - 3. distance ordering: adjacent < same-row < cross-row

    func test_distance_ordering_adjacentLessThanSameRowLessThanCrossRow() {
        // adjacent:  f (2,4) → g (2,5) = 1.0
        // same-row:  f (2,4) → j (2,7) = 3.0
        // cross-row: a (2,1) → 5 (0,6) = √((1-6)²+(2-0)²) = √29 ≈ 5.385
        let posF = layout.position(for: "f")!
        let posG = layout.position(for: "g")!
        let posJ = layout.position(for: "j")!
        let posA = layout.position(for: "a")!
        let pos5 = layout.position(for: "5")!

        let adjacent  = estimator.distance(from: posF, to: posG)  // 1.0
        let sameRow   = estimator.distance(from: posF, to: posJ)  // 3.0
        let crossRow  = estimator.distance(from: posA, to: pos5)  // √29

        XCTAssertLessThan(adjacent, sameRow,  "adjacent key distance must be < same-row wider distance")
        XCTAssertLessThan(sameRow,  crossRow, "same-row distance must be < cross-row distance")
    }

    // MARK: - 4. distance: configurable scale

    func test_distance_customScale_appliesCorrectly() {
        // f (2,4) → g (2,5): col diff = 1 → distance = 1 × columnWidth
        let posF = layout.position(for: "f")!
        let posG = layout.position(for: "g")!
        let scaled = TravelDistanceEstimator(columnWidth: 2.5, rowHeight: 1.0)
        XCTAssertEqual(scaled.distance(from: posF, to: posG), 2.5, accuracy: 1e-10)
    }

    func test_distance_rowScale_appliesCorrectly() {
        // f (2,4) → r (1,4): row diff = 1, col diff = 0 → distance = 1 × rowHeight
        let posF = layout.position(for: "f")!
        let posR = layout.position(for: "r")!
        let scaled = TravelDistanceEstimator(columnWidth: 1.0, rowHeight: 1.5)
        XCTAssertEqual(scaled.distance(from: posF, to: posR), 1.5, accuracy: 1e-10)
    }

    // MARK: - 5. totalTravel: empty counts

    func test_totalTravel_emptyCounts_isZero() {
        XCTAssertEqual(estimator.totalTravel(counts: [:], layout: layout), 0.0)
    }

    // MARK: - 6. totalTravel: single bigram

    func test_totalTravel_singleBigram_equalsCountTimesDistance() {
        // a (2,1) → l (2,9): col diff = 8 → distance = 8.0, count = 100 → travel = 800.0
        let counts = ["a→l": 100]
        XCTAssertEqual(estimator.totalTravel(counts: counts, layout: layout), 800.0, accuracy: 1e-10)
    }

    // MARK: - 7. totalTravel: multiple bigrams accumulate

    func test_totalTravel_multipleBigrams_accumulates() {
        // f→g: distance 1.0, count 200 → 200.0
        // a→l: distance 8.0, count 50  → 400.0
        // expected total = 600.0
        let counts = ["f→g": 200, "a→l": 50]
        XCTAssertEqual(estimator.totalTravel(counts: counts, layout: layout), 600.0, accuracy: 1e-10)
    }

    // MARK: - 8. totalTravel: unknown key is skipped

    func test_totalTravel_unknownKey_isSkipped() {
        // "f→UNKNOWN" should be silently ignored; only "f→g" contributes
        let counts = ["f→UNKNOWN": 999, "f→g": 10]
        XCTAssertEqual(estimator.totalTravel(counts: counts, layout: layout), 10.0, accuracy: 1e-10)
    }

    // MARK: - 9. totalTravel: zero-count bigram is skipped

    func test_totalTravel_zeroCountBigram_isSkipped() {
        let counts = ["f→g": 0, "a→l": 5]
        XCTAssertEqual(estimator.totalTravel(counts: counts, layout: layout), 40.0, accuracy: 1e-10)
    }

    // MARK: - 10. projectedTravel: swap reduces travel for a distant-key bigram

    func test_projectedTravel_swap_reducesTravel() {
        // "a→l" baseline: a(2,1) and l(2,9) are 8 columns apart → travel = 8000.0
        // Swap "a" ↔ "k": a moves to k's position (2,8), l stays at (2,9)
        // After swap: distance("a→l") = |8-9| = 1.0 → projected travel = 1000.0
        let counts = ["a→l": 1000]
        let baseline = estimator.totalTravel(counts: counts, layout: layout)
        XCTAssertEqual(baseline, 8000.0, accuracy: 1e-10)

        var relocation: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "a", key2: "k", to: &relocation)
        let projected = estimator.projectedTravel(counts: counts, relocation: relocation, layout: layout)

        XCTAssertLessThan(projected, baseline, "swapping 'a' closer to 'l' must reduce travel")
        XCTAssertEqual(projected, 1000.0, accuracy: 1e-10)
    }

    // MARK: - 11. projectedTravel: identity relocation equals totalTravel

    func test_projectedTravel_emptyRelocation_equalsTotalTravel() {
        let counts = ["f→g": 100, "a→l": 50]
        let total     = estimator.totalTravel(counts: counts, layout: layout)
        let projected = estimator.projectedTravel(counts: counts, relocation: [:], layout: layout)
        XCTAssertEqual(projected, total, accuracy: 1e-10)
    }

    // MARK: - 12. ErgonomicSnapshot.capture

    func test_ergonomicSnapshot_capture_matchesTotalTravel() {
        // bigramCounts only (no thumb keys in test data → keyCounts can be empty).
        // テストデータに親指キーが含まれないため keyCounts は空で問題ない。
        let bigramCounts = ["f→g": 200, "a→l": 50]
        let expected = estimator.totalTravel(counts: bigramCounts, layout: layout)
        let snapshot = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts:    [:],
            layout:       LayoutRegistry.shared
        )
        XCTAssertEqual(snapshot.estimatedTravelDistance, expected, accuracy: 1e-10)
    }

    func test_ergonomicSnapshot_equatable() {
        let bigramCounts = ["f→g": 100]
        let s1 = ErgonomicSnapshot.capture(bigramCounts: bigramCounts, keyCounts: [:], layout: LayoutRegistry.shared)
        let s2 = ErgonomicSnapshot.capture(bigramCounts: bigramCounts, keyCounts: [:], layout: LayoutRegistry.shared)
        XCTAssertEqual(s1, s2)
    }
}
