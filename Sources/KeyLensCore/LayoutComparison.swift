// LayoutComparison.swift
// Side-by-side ergonomic evaluation of a current layout versus a proposed layout.
// 現行レイアウトと提案レイアウトのエルゴノミクス指標を並べて比較するデータ型。
//
// ## Design
//
// LayoutComparison holds two ErgonomicSnapshot values (current / proposed) and
// exposes signed delta properties so the UI can render direction arrows and colour coding.
//
// Delta convention: positive delta = improvement in ergonomics.
//   ergonomicScoreDelta    > 0  → proposed score is higher (better)
//   sameFingerRateDelta    > 0  → proposed SFB rate is lower  (better)
//   handAlternationDelta   > 0  → proposed alternation rate is higher (better)
//   highStrainRateDelta    > 0  → proposed high-strain rate is lower  (better)
//   thumbImbalanceDelta    > 0  → proposed imbalance is lower (better)
//   travelDistanceDelta    > 0  → proposed travel distance is lower (better)
//
// LayoutComparison.make(bigramCounts:keyCounts:) is the primary convenience factory.
// It runs SameFingerOptimizer to find the best key swaps, builds a RemappedLayout,
// and computes both snapshots in one call.
//
// デルタ正値 = エルゴノミクス改善。make() がオプティマイザを実行して両スナップショットを算出。
//
// ## Phase
// Phase 2 – Optimization Engine (Issue #3)

import Foundation

// MARK: - LayoutComparison

/// Side-by-side ergonomic comparison between a current layout and a proposed optimised layout.
///
/// Usage:
/// ```swift
/// if let comparison = LayoutComparison.make(
///     bigramCounts: store.allBigramCounts,
///     keyCounts:    store.allKeyCounts
/// ) {
///     print("Score improvement: \(comparison.ergonomicScoreDelta)")
/// }
/// ```
///
/// 現行レイアウトと最適化提案レイアウトのエルゴノミクス指標を並べて比較する。
public struct LayoutComparison: Equatable {

    /// Ergonomic snapshot for the user's current layout and typing data.
    /// 現行レイアウトでの打鍵データに対するエルゴノミクススナップショット。
    public let current: ErgonomicSnapshot

    /// Ergonomic snapshot for the proposed (optimised) layout, applied to the same data.
    /// 同一打鍵データに対して最適化提案レイアウトを適用したスナップショット。
    public let proposed: ErgonomicSnapshot

    /// The key relocations recommended by the optimizer, in order of projected improvement.
    /// オプティマイザが提案するキー移動（改善量降順）。
    public let recommendedSwaps: [ErgonomicSwap]

    public init(current: ErgonomicSnapshot, proposed: ErgonomicSnapshot, recommendedSwaps: [ErgonomicSwap]) {
        self.current          = current
        self.proposed         = proposed
        self.recommendedSwaps = recommendedSwaps
    }

    // MARK: - Delta properties (positive = improvement)

    /// Change in composite ergonomic score. Positive = proposed is better.
    /// 統合スコアの変化量。正値 = 提案の方が良い。
    public var ergonomicScoreDelta: Double {
        proposed.ergonomicScore - current.ergonomicScore
    }

    /// Change in same-finger bigram rate. Positive = proposed has fewer SFBs (better).
    /// 同指ビグラム率の変化量。正値 = 提案の方が少ない（良い）。
    public var sameFingerRateDelta: Double {
        current.sameFingerRate - proposed.sameFingerRate
    }

    /// Change in hand alternation rate. Positive = proposed alternates more (better).
    /// 手交互打鍵率の変化量。正値 = 提案の方が多い（良い）。
    public var handAlternationDelta: Double {
        proposed.handAlternationRate - current.handAlternationRate
    }

    /// Change in high-strain bigram rate. Positive = proposed has fewer high-strain bigrams (better).
    /// 高負荷ビグラム率の変化量。正値 = 提案の方が少ない（良い）。
    public var highStrainRateDelta: Double {
        current.highStrainRate - proposed.highStrainRate
    }

    /// Change in thumb imbalance ratio. Positive = proposed is more balanced (better).
    /// 親指偏り比率の変化量。正値 = 提案の方が均等（良い）。
    public var thumbImbalanceDelta: Double {
        current.thumbImbalanceRatio - proposed.thumbImbalanceRatio
    }

    /// Change in estimated finger travel distance. Positive = proposed requires less travel (better).
    /// 推定指移動距離の変化量。正値 = 提案の方が少ない（良い）。
    public var travelDistanceDelta: Double {
        current.estimatedTravelDistance - proposed.estimatedTravelDistance
    }

    // MARK: - Convenience factory

    /// Builds a LayoutComparison by running the SameFingerOptimizer and computing both snapshots.
    ///
    /// - Parameters:
    ///   - bigramCounts: Bigram frequency map from KeyCountStore.allBigramCounts.
    ///   - keyCounts:    Per-key keystroke count from KeyCountStore.allKeyCounts.
    ///   - maxSwaps:     Maximum number of key swaps to propose (default 3).
    ///   - base:         Layout registry to evaluate against (default: LayoutRegistry.shared).
    ///   - estimator:    Travel distance estimator (default: .default).
    /// - Returns: A LayoutComparison, or `nil` if bigramCounts is empty or no beneficial swap exists.
    ///
    /// SameFingerOptimizer を実行し、現行・提案の両スナップショットを算出して返す。
    /// bigramCounts が空またはスワップが存在しない場合は nil。
    public static func make(
        bigramCounts: [String: Int],
        keyCounts:    [String: Int],
        maxSwaps:     Int = 3,
        base:         LayoutRegistry = .shared,
        estimator:    TravelDistanceEstimator = .default
    ) -> LayoutComparison? {
        guard !bigramCounts.isEmpty else { return nil }

        // 1. Compute current snapshot.
        // 現行レイアウトのスナップショットを計算する。
        let currentSnapshot = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts:    keyCounts,
            layout:       base,
            estimator:    estimator
        )

        // 2. Run FullErgonomicOptimizer to find beneficial relocations.
        // FullErgonomicOptimizer で統合スコアを最大化する配置を探索する。
        let optimizer = FullErgonomicOptimizer()
        let swaps = optimizer.optimize(
            bigramCounts: bigramCounts,
            keyCounts:    keyCounts,
            layout:       base,
            maxSwaps:     maxSwaps
        )
        guard !swaps.isEmpty else { return nil }

        // 3. Build a RemappedLayout applying all recommended swaps.
        // 全推奨スワップを適用した RemappedLayout を構築する。
        var relocationMap: [String: String] = [:]
        for swap in swaps {
            KeyRelocationSimulator.applySwap(key1: swap.from, key2: swap.to, to: &relocationMap)
        }
        let remappedLayout = KeyRelocationSimulator.layout(
            applying: relocationMap,
            over:     base.current
        )

        // 4. Create a simulation registry and compute the proposed snapshot.
        // シミュレーション用レジストリを生成して提案スナップショットを計算する。
        let simRegistry = LayoutRegistry.forSimulation(layout: remappedLayout, base: base)
        let proposedSnapshot = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts:    keyCounts,
            layout:       simRegistry,
            estimator:    estimator
        )

        return LayoutComparison(
            current:          currentSnapshot,
            proposed:         proposedSnapshot,
            recommendedSwaps: swaps
        )
    }
}
