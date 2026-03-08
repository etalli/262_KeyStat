// FullErgonomicOptimizer.swift
// Hill-climb optimizer that finds key relocations maximizing the unified ergonomic score.
// 統合エルゴノミクススコアを最大化するキー配置を探索するヒルクライムオプティマイザ。
//
// ## Algorithm
//
// 1. Build the set of "relocatable" keys: keys that appear in the data and are NOT in LayoutConstraints.fixedKeys.
// 2. Compute the baseline ErgonomicSnapshot with the unmodified layout.
// 3. Iteration (repeated up to maxSwaps times):
//    a. Identify candidate keys: High-frequency keys on weak fingers or high-SFB contributors.
//    b. For each (candidate, any-relocatable) pair, simulate the swap.
//    c. Compute the new ErgonomicSnapshot and the corresponding ergonomicScore.
//    d. Accept the swap with the largest score improvement.
//    e. If no improvement is found, stop early.
//
// 4. Return the ordered list of accepted swaps.
//
// 統合スコア（SFB、高負荷、手交互、親指、移動距離）を総合的に評価して最適化を行う。
//
// ## Phase
// Phase 2 – Optimization Engine (Issue #41)

import Foundation

// MARK: - ErgonomicSwap

/// A recommended key relocation with its projected impact on the unified score.
/// 推奨されるキー移動と、統合スコアへの予測影響。
public struct ErgonomicSwap: Equatable {
    /// The key whose current position will be swapped.
    public let from: String
    /// The key it will be swapped with.
    public let to: String
    /// Improvement in the unified ergonomic score [0, 100].
    /// 統合エルゴノミクススコアの改善量。
    public let projectedScoreImprovement: Double

    public init(from: String, to: String, projectedScoreImprovement: Double) {
        self.from = from
        self.to = to
        self.projectedScoreImprovement = projectedScoreImprovement
    }
}

// MARK: - FullErgonomicOptimizer

/// Optimizer that identifies key swaps maximizing the unified ergonomic score.
/// 統合エルゴノミクススコアを最大化するキースワップを特定するオプティマイザ。
public struct FullErgonomicOptimizer {

    /// Maximum number of candidate keys to test per iteration (for performance).
    public let candidateLimit: Int

    public init(candidateLimit: Int = 15) {
        self.candidateLimit = candidateLimit
    }

    // MARK: - Public API

    /// Finds an ordered list of key swaps that progressively increase the ergonomic score.
    ///
    /// - Parameters:
    ///   - bigramCounts: Bigram frequency map.
    ///   - keyCounts: Per-key frequency map.
    ///   - layout: The base layout registry to optimize against.
    ///   - constraints: Keys that must not be moved.
    ///   - maxSwaps: Maximum number of swaps to propose.
    /// - Returns: Ordered list of `ErgonomicSwap` values.
    public func optimize(
        bigramCounts: [String: Int],
        keyCounts: [String: Int],
        layout: LayoutRegistry = .shared,
        constraints: LayoutConstraints = .macOSDefaults,
        maxSwaps: Int = 3
    ) -> [ErgonomicSwap] {
        guard !bigramCounts.isEmpty, maxSwaps > 0 else { return [] }

        // 1. Build relocatable key set: in data, in layout, not fixed.
        let allKeysInData = keysInData(bigramCounts, keyCounts)
        let relocatable = allKeysInData.filter { key in
            !constraints.fixedKeys.contains(key) && layout.current.position(for: key) != nil
        }
        guard relocatable.count >= 2 else { return [] }

        var result: [ErgonomicSwap] = []
        var currentMap: [String: String] = [:]
        
        let currentSnapshot = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout
        )
        var currentScore = currentSnapshot.ergonomicScore

        for _ in 0..<maxSwaps {
            // 2a. Identify candidate keys to test (e.g., top frequency keys).
            // In a more advanced version, we could include keys involved in SFBs.
            let candidates = relocatable
                .map { (key: $0, count: keyCounts[$0] ?? 0) }
                .sorted { $0.count > $1.count }
                .prefix(candidateLimit)
                .map { $0.key }

            var bestImprovement = 0.0
            var bestPair: (String, String)? = nil

            // 2b. Test candidate swaps.
            for candidate in candidates {
                for other in relocatable where other != candidate {
                    var proposedMap = currentMap
                    KeyRelocationSimulator.applySwap(key1: candidate, key2: other, to: &proposedMap)
                    
                    let simulatedLayout = KeyRelocationSimulator.layout(applying: proposedMap, over: layout.current)
                    let simRegistry = LayoutRegistry.forSimulation(layout: simulatedLayout, base: layout)
                    
                    let simSnapshot = ErgonomicSnapshot.capture(
                        bigramCounts: bigramCounts,
                        keyCounts: keyCounts,
                        layout: simRegistry
                    )
                    
                    let improvement = simSnapshot.ergonomicScore - currentScore
                    if improvement > bestImprovement {
                        bestImprovement = improvement
                        bestPair = (candidate, other)
                    }
                }
            }

            // 2c. Accept the best swap.
            guard let (k1, k2) = bestPair, bestImprovement > 0.001 else { break }
            KeyRelocationSimulator.applySwap(key1: k1, key2: k2, to: &currentMap)
            currentScore += bestImprovement
            result.append(ErgonomicSwap(from: k1, to: k2, projectedScoreImprovement: bestImprovement))
        }

        return result
    }

    // MARK: - Private helpers

    private func keysInData(_ bigramCounts: [String: Int], _ keyCounts: [String: Int]) -> Set<String> {
        var keys = Set(keyCounts.keys)
        for bigram in bigramCounts.keys {
            let parts = bigram.components(separatedBy: "→")
            if parts.count == 2 {
                keys.insert(parts[0])
                keys.insert(parts[1])
            }
        }
        return keys
    }
}
