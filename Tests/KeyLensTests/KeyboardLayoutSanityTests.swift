import XCTest
import CoreGraphics
@testable import KeyLensCore

final class KeyboardLayoutSanityTests: XCTestCase {

    func testANSITableContainsRequiredAnchorKeys() {
        // Avoid brittle exact-count checks; ensure essential anchor keys remain mapped.
        let required: [CGKeyCode] = [
            0,    // A
            49,   // Space
            53,   // Escape
            54,   // Right Cmd
            55,   // Left Cmd
            56,   // Left Shift
            60,   // Right Shift
            123,  // Left Arrow
            124,  // Right Arrow
            125,  // Down Arrow
            126   // Up Arrow
        ]

        for code in required {
            XCTAssertNotNil(ANSILayout.table[code], "Missing required key mapping: \(code)")
        }
    }

    func testStandardSplitMatchesHandTableSets() {
        let split = SplitKeyboardConfig.standardSplit
        let left = Set(ANSILayout.handTable.filter { $0.value == .left }.keys)
        let right = Set(ANSILayout.handTable.filter { $0.value == .right }.keys)

        XCTAssertEqual(split.leftKeys, left)
        XCTAssertEqual(split.rightKeys, right)
    }

    func testKeyCodeFallbackRejectsInvalidFormats() {
        let layout = ANSILayout()

        XCTAssertNil(layout.hand(for: "Key(x)"))
        XCTAssertNil(layout.hand(for: "Key(999)"))
        XCTAssertNil(layout.finger(for: "Key(x)"))
        XCTAssertNil(layout.finger(for: "Key(999)"))
    }

    func testRepresentativeKeyCodeFallbacksResolve() {
        let layout = ANSILayout()

        // Right Cmd
        XCTAssertEqual(layout.hand(for: "Key(54)"), .right)
        XCTAssertEqual(layout.finger(for: "Key(54)"), .thumb)

        // Right Shift
        XCTAssertEqual(layout.hand(for: "Key(60)"), .right)
        XCTAssertEqual(layout.finger(for: "Key(60)"), .pinky)
    }
}
