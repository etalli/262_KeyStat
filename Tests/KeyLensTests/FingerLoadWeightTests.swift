import XCTest
@testable import KeyLensCore

// Tests for FingerLoadWeight (Issue #23 — Phase 1 core).
//
// FingerLoadWeight assigns a relative capability score to each finger.
// A weight of 1.0 means "strongest / least fatiguing per keystroke" (index finger baseline).
// Lower weights (e.g. pinky = 0.5) mean the same number of keystrokes costs MORE ergonomic load.
//
// These tests verify:
//   1. The default Carpalx / Kim et al. reference values are correct.
//   2. Custom weight tables work and missing fingers fall back safely.
//   3. LayoutRegistry.loadWeight(for:) correctly maps key names → finger → weight.
//   4. The weight table on LayoutRegistry can be swapped at runtime.
//
// 指負荷重みの基礎テスト。
// 重みが低い指（小指 0.5）は同じ打鍵数でも疲労コストが高いとみなす。
// Phase 1 のエルゴノミクススコア計算全体の土台となる。

final class FingerLoadWeightTests: XCTestCase {

    // MARK: - Default weights
    //
    // Verify each finger's default weight matches the Carpalx reference values.
    // These numbers are the foundation for all downstream ergonomic scoring (Issue #29).
    // デフォルト値が参照文献（Carpalx / Kim et al.）と一致することを確認する。

    func testDefault_index() {
        // Index finger is the baseline — strongest, widest lateral reach.
        // 人差し指は基準値（最強・最広域）。
        XCTAssertEqual(FingerLoadWeight.default.weight(for: .index), 1.0)
    }

    func testDefault_middle() {
        // Middle finger is nearly as strong as index; slight reduction for coordination overhead.
        // 中指は人差し指に次ぐ強さ。わずかに劣るため 0.9。
        XCTAssertEqual(FingerLoadWeight.default.weight(for: .middle), 0.9)
    }

    func testDefault_thumb() {
        // Thumb is strong but limited to very few keys (Space, Cmd, Option).
        // 親指は力があるが担当キーが少なく、独立性も低いため 0.8。
        XCTAssertEqual(FingerLoadWeight.default.weight(for: .thumb), 0.8)
    }

    func testDefault_ring() {
        // Ring finger shares tendons with middle and pinky, reducing independent movement.
        // 薬指は中指・小指と腱を共有するため独立性が低く、疲れやすい。
        XCTAssertEqual(FingerLoadWeight.default.weight(for: .ring), 0.6)
    }

    func testDefault_pinky() {
        // Pinky is the weakest finger with the shortest reach.
        // Assigning high-frequency keys to it is a primary cause of typing fatigue.
        // 小指は最弱・最短リーチ。高頻度キーを割り当てると疲労の主因になる。
        XCTAssertEqual(FingerLoadWeight.default.weight(for: .pinky), 0.5)
    }

    func testDefault_allFingersAreCovered() {
        // Guard against accidentally omitting a Finger case from the default table.
        // Finger.allCases iterates every case in the enum — if a new finger is added later,
        // this test will catch missing entries.
        // デフォルトテーブルに Finger の全 case が含まれていることを保証する。
        let w = FingerLoadWeight.default
        for finger in Finger.allCases {
            XCTAssertNotNil(w.weights[finger], "Missing weight for \(finger)")
        }
    }

    // MARK: - Custom weights
    //
    // FingerLoadWeight accepts arbitrary values so researchers can experiment
    // with alternative weighting models (e.g. equal weights, user-measured values).
    // 研究・カスタマイズ用途で任意の重みを設定できることを確認する。

    func testCustomWeights() {
        // Custom table with only two entries — both should be retrievable as-is.
        let custom = FingerLoadWeight(weights: [.index: 2.0, .pinky: 0.1])
        XCTAssertEqual(custom.weight(for: .index), 2.0)
        XCTAssertEqual(custom.weight(for: .pinky), 0.1)
    }

    func testMissingFingerFallsBackToOne() {
        // When a finger is absent from the table, weight(for:) returns 1.0 (neutral / no penalty).
        // This prevents a crash if a sparse table is supplied.
        // テーブルにない指は 1.0（ペナルティなし）にフォールバックし、クラッシュしない。
        let sparse = FingerLoadWeight(weights: [.index: 1.0])
        XCTAssertEqual(sparse.weight(for: .ring), 1.0)
    }

    // MARK: - LayoutRegistry.loadWeight(for keyName:)
    //
    // LayoutRegistry.loadWeight(for:) is the public API that downstream scorers will call.
    // It resolves: key name → finger (via ANSILayout.fingerTable) → weight.
    // LayoutRegistry.loadWeight(for:) はスコア計算が呼び出す公開 API。
    // キー名 → 指 → 重み の変換パイプラインをエンドツーエンドで検証する。

    func testLoadWeight_indexFinger() {
        // "f" = left index home key; "j" = right index home key.
        // Both should yield the index weight of 1.0.
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "f"), 1.0)
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "j"), 1.0)
    }

    func testLoadWeight_middleFinger() {
        // "d" = left middle home key; "k" = right middle home key.
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "d"), 0.9)
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "k"), 0.9)
    }

    func testLoadWeight_thumbFinger() {
        // Space is the primary thumb key on ANSI layout.
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "Space"), 0.8)
    }

    func testLoadWeight_ringFinger() {
        // "s" = left ring home key; "l" = right ring home key.
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "s"), 0.6)
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "l"), 0.6)
    }

    func testLoadWeight_pinkyFinger() {
        // "a" = left pinky home key. Return and Delete are also pinky keys —
        // confirming that high-frequency modifier/navigation keys load the weakest finger.
        // "a"・Return・Delete はいずれも小指キー。頻度の高いキーが最弱指に集中していることを示す。
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "a"),      0.5)
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "Return"), 0.5)
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "Delete"), 0.5)
    }

    func testLoadWeight_unknownKeyReturnsNil() {
        // Mouse events and unrecognized strings have no finger assignment → nil.
        // Callers must handle nil (e.g. skip mouse clicks in ergonomic scoring).
        // マウスイベントや未知キーは指が割り当てられないため nil を返す。
        XCTAssertNil(LayoutRegistry.shared.loadWeight(for: "🖱Left"))
        XCTAssertNil(LayoutRegistry.shared.loadWeight(for: "unknown"))
    }

    // MARK: - Runtime weight replacement via LayoutRegistry
    //
    // The active weight table on LayoutRegistry.shared can be swapped at runtime,
    // enabling future UI settings or A/B testing of different weighting models.
    // LayoutRegistry の重みテーブルを実行時に差し替えられることを確認する。

    func testRegistry_customFingerLoadWeight() {
        let original = LayoutRegistry.shared.activeProfile
        defer { LayoutRegistry.shared.activeProfile = original }

        // Replace with a flat profile
        LayoutRegistry.shared.activeProfile = ErgonomicProfile(
            name: "Flat",
            fingerWeights: FingerLoadWeight(weights: [
                .index: 1.0, .middle: 1.0, .thumb: 1.0, .ring: 1.0, .pinky: 1.0
            ])
        )
        XCTAssertEqual(LayoutRegistry.shared.loadWeight(for: "a"), 1.0)
    }
}
