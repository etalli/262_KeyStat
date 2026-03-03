import XCTest
@testable import KeyLensCore

// Tests for general trigram frequency logic (Issue #12 — Phase 0).
//
// ## What is being tested
//
// Trigrams are recorded in KeyCountStore.increment() using a 3-key rolling
// window (secondLastKeyName, lastKeyName, key). The tests here validate the
// structural rules of that logic using KeyLensCore models directly, since
// KeyCountStore requires an App Bundle and cannot be unit-tested.
//
// 1. Key format — trigrams use "→" separator: "a→s→d"
// 2. Rolling window semantics
//    - 1 key:  no bigram, no trigram
//    - 2 keys: bigram only, no trigram
//    - 3 keys: first trigram recorded (A→B→C)
//    - 4 keys: second trigram recorded (B→C→D), not A→B→C again
// 3. Chain break — unmapped keys (mouse clicks) reset secondLastKeyName,
//    preventing stale trigrams across an interruption.
// 4. Key lookup — ANSILayout can resolve finger/hand for all keys used in tests.

final class TrigramCountsTests: XCTestCase {

    private let layout = ANSILayout()

    // MARK: - 1. Key format

    func test_trigramKeyFormat_usesArrowSeparator() {
        let trigram = "a→s→d"
        let parts = trigram.components(separatedBy: "→")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "a")
        XCTAssertEqual(parts[1], "s")
        XCTAssertEqual(parts[2], "d")
    }

    func test_trigramKeyFormat_distinctFromBigram() {
        let bigram   = "a→s"
        let trigram  = "a→s→d"
        XCTAssertNotEqual(bigram, trigram)
        XCTAssertEqual(bigram.components(separatedBy: "→").count, 2)
        XCTAssertEqual(trigram.components(separatedBy: "→").count, 3)
    }

    // MARK: - 2. Rolling window semantics

    // Simulate the rolling window logic that lives in KeyCountStore.increment().
    // Returns the list of trigrams that would have been recorded for a given key sequence.
    private func simulateTrigrams(keys: [String]) -> [String] {
        var lastKey: String? = nil
        var secondLastKey: String? = nil
        var recorded: [String] = []

        for key in keys {
            let prevMapped = lastKey.flatMap { layout.finger(for: $0) } != nil
            let curMapped  = layout.finger(for: key) != nil

            if let prev = lastKey, prevMapped, curMapped {
                // Valid bigram — check for trigram
                if let prev2 = secondLastKey {
                    recorded.append("\(prev2)→\(prev)→\(key)")
                }
                secondLastKey = prev   // advance window inside guard
            } else {
                secondLastKey = nil    // chain broken
            }
            lastKey = key
        }
        return recorded
    }

    func test_oneKey_noTrigram() {
        XCTAssertEqual(simulateTrigrams(keys: ["a"]), [])
    }

    func test_twoKeys_noTrigram() {
        XCTAssertEqual(simulateTrigrams(keys: ["a", "s"]), [])
    }

    func test_threeKeys_firstTrigram() {
        let result = simulateTrigrams(keys: ["a", "s", "d"])
        XCTAssertEqual(result, ["a→s→d"])
    }

    func test_fourKeys_slidingWindow() {
        // A→B→C then B→C→D (not A→B→C again)
        let result = simulateTrigrams(keys: ["a", "s", "d", "f"])
        XCTAssertEqual(result, ["a→s→d", "s→d→f"])
    }

    func test_fiveKeys_threeTrigramms() {
        let result = simulateTrigrams(keys: ["f", "r", "t", "g", "v"])
        XCTAssertEqual(result, ["f→r→t", "r→t→g", "t→g→v"])
    }

    // MARK: - 3. Chain break — unmapped key resets window

    func test_mouseClick_breaksChain_noStaleTrigramAfter() {
        // a, s, [mouse click "🖱Left" = unmapped], d, f
        // Bigrams: a→s (valid), d→f (valid after break)
        // Trigrams: none (chain broke at mouse click)
        let result = simulateTrigrams(keys: ["a", "s", "🖱Left", "d", "f"])
        // "🖱Left→d→f" must NOT appear; "a→s→d" must NOT appear
        XCTAssertFalse(result.contains("a→s→🖱Left"))
        XCTAssertFalse(result.contains("🖱Left→d→f"))
        XCTAssertFalse(result.contains("a→s→d"))
        // After chain resumes with d→f, secondLast is nil → no trigram yet
        XCTAssertEqual(result, [])
    }

    func test_mouseClick_then_threeMore_resumesChain() {
        // a, s, [🖱Left], d, f, g
        // After break: d, f, g → trigram "d→f→g"
        let result = simulateTrigrams(keys: ["a", "s", "🖱Left", "d", "f", "g"])
        XCTAssertEqual(result, ["d→f→g"])
    }

    func test_twoConsecutiveMouseClicks_doubleBreak() {
        let result = simulateTrigrams(keys: ["a", "🖱Left", "🖱Right", "s", "d", "f"])
        XCTAssertEqual(result, ["s→d→f"])
    }

    // MARK: - 4. Key lookup sanity

    func test_allTestKeysAreMappedInANSI() {
        let testKeys = ["a", "s", "d", "f", "r", "t", "g", "v"]
        for key in testKeys {
            XCTAssertNotNil(layout.finger(for: key), "\(key) should be mapped in ANSILayout")
            XCTAssertNotNil(layout.hand(for: key),   "\(key) should have a hand in ANSILayout")
        }
    }

    func test_mouseClickKeyIsUnmappedInANSI() {
        XCTAssertNil(layout.finger(for: "🖱Left"),  "mouse click should not be in ANSILayout")
        XCTAssertNil(layout.finger(for: "🖱Right"), "mouse click should not be in ANSILayout")
    }
}
