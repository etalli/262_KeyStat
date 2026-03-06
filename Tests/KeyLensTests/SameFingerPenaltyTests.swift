import XCTest
import CoreGraphics
@testable import KeyLensCore

final class SameFingerPenaltyTests: XCTestCase {

    let model = SameFingerPenalty.default

    private func pos(_ row: Int, _ col: Int) -> KeyPosition {
        KeyPosition(row: row, column: col, hand: .left, finger: .index)
    }

    func testTier_sameKey() {
        let p = pos(2, 4)
        XCTAssertEqual(model.tier(from: p, to: p), .sameKey)
    }

    func testTier_adjacent_sameRowDifferentColumn() {
        let f = pos(2, 4)
        let g = pos(2, 5)
        XCTAssertEqual(model.tier(from: f, to: g), .adjacent)
        XCTAssertEqual(model.tier(from: g, to: f), .adjacent)
    }

    func testTier_adjacent_largeColumnGap_sameRow() {
        let left  = pos(2, 0)
        let right = pos(2, 10)
        XCTAssertEqual(model.tier(from: left, to: right), .adjacent)
    }

    func testTier_oneRow() {
        let f = pos(2, 4)
        let r = pos(1, 4)
        XCTAssertEqual(model.tier(from: f, to: r), .oneRow)
        XCTAssertEqual(model.tier(from: r, to: f), .oneRow)
    }

    func testTier_multiRow_twoRows() {
        let f     = pos(2, 4)
        let num4  = pos(0, 5)
        XCTAssertEqual(model.tier(from: f, to: num4), .multiRow)
    }

    func testTier_multiRow_threeRows() {
        let fn = pos(5, 4)
        let hr = pos(2, 4)
        XCTAssertEqual(model.tier(from: fn, to: hr), .multiRow)
    }

    func testFactor_sameKey()  { XCTAssertEqual(model.factor(for: .sameKey),  0.5) }
    func testFactor_adjacent() { XCTAssertEqual(model.factor(for: .adjacent), 1.0) }
    func testFactor_oneRow()   { XCTAssertEqual(model.factor(for: .oneRow),   2.0) }
    func testFactor_multiRow() { XCTAssertEqual(model.factor(for: .multiRow), 4.0) }

    func testPenalty_sameKey_indexWeight() {
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(2,4), fingerWeight: 1.0), 0.25)
    }

    func testPenalty_adjacent_indexWeight() {
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(2,5), fingerWeight: 1.0), 1.0)
    }

    func testPenalty_oneRow_indexWeight() {
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(1,4), fingerWeight: 1.0), 4.0)
    }

    func testPenalty_multiRow_indexWeight() {
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(0,5), fingerWeight: 1.0), 16.0)
    }

    func testPenalty_oneRow_pinkyWeight() {
        XCTAssertEqual(model.penalty(from: pos(2,0), to: pos(1,0), fingerWeight: 0.5), 2.0)
    }

    func testPenalty_multiRow_pinkyWeight() {
        XCTAssertEqual(model.penalty(from: pos(2,0), to: pos(0,0), fingerWeight: 0.5), 8.0)
    }

    func testPenalty_linearExponent() {
        let linear = SameFingerPenalty(exponent: 1.0)
        XCTAssertEqual(linear.penalty(from: pos(2,4), to: pos(1,4), fingerWeight: 1.0), 2.0)
        XCTAssertEqual(linear.penalty(from: pos(2,4), to: pos(0,5), fingerWeight: 1.0), 4.0)
    }

    func testPenalty_cubicExponent() {
        let cubic = SameFingerPenalty(exponent: 3.0)
        XCTAssertEqual(cubic.penalty(from: pos(2,4), to: pos(1,4), fingerWeight: 1.0), 8.0)
    }

    func testSameFingerPenalty_adjacent_fToG() {
        LayoutRegistry.shared.activeProfile = .standard
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "f→g")
        XCTAssertEqual(p, 1.0)
    }

    func testSameFingerPenalty_oneRow_fToR() {
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "f→r")
        XCTAssertEqual(p, 4.0)
    }

    func testSameFingerPenalty_multiRow_fTo4() {
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "f→4")
        XCTAssertEqual(p, 16.0)
    }

    func testSameFingerPenalty_sameKey_space() {
        LayoutRegistry.shared.activeProfile = .standard
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "Space→Space")
        XCTAssertEqual(p!, 0.2, accuracy: 1e-10)
    }

    func testSameFingerPenalty_crossHand_returnsNil() {
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "f→j"))
    }

    func testSameFingerPenalty_differentFinger_returnsNil() {
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "f→s"))
    }

    func testSameFingerPenalty_unknownKey_returnsNil() {
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "unknown→f"))
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "🖱Left→f"))
    }

    func testSameFingerPenalty_malformedBigram_returnsNil() {
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "fg"))
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: ""))
    }

    func testPositionNameTable_homeRowKeys() {
        let layout = ANSILayout()
        for key in ["a", "s", "d", "f", "g", "h", "j", "k", "l"] {
            XCTAssertNotNil(layout.position(for: key), "Missing position for '\(key)'")
        }
    }

    func testPositionNameTable_spaceAndModifiers() {
        let layout = ANSILayout()
        XCTAssertNotNil(layout.position(for: "Space"))
        XCTAssertNotNil(layout.position(for: "⌘Cmd"))
        XCTAssertNotNil(layout.position(for: "⇧Shift"))
    }

    func testPositionNameTable_unknownReturnsNil() {
        let layout = ANSILayout()
        XCTAssertNil(layout.position(for: "🖱Left"))
        XCTAssertNil(layout.position(for: "unknown"))
    }
}
