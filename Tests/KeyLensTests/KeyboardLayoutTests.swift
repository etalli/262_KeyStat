import XCTest
import CoreGraphics
@testable import KeyLensCore

final class KeyboardLayoutTests: XCTestCase {

    let layout = ANSILayout()

    // MARK: - Layout name

    func testLayoutName() {
        XCTAssertEqual(layout.name, "ANSI")
    }

    // MARK: - Unknown key returns nil

    func testUnknownKeyCode() {
        XCTAssertNil(layout.position(for: 255))
        XCTAssertNil(layout.position(for: 200))
    }

    // MARK: - Home row (row 2)

    func testHomeRow_A() {
        let pos = layout.position(for: 0)  // A
        XCTAssertEqual(pos?.row,    2)
        XCTAssertEqual(pos?.column, 1)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    func testHomeRow_S() {
        let pos = layout.position(for: 1)  // S
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .ring)
    }

    func testHomeRow_F() {
        let pos = layout.position(for: 3)  // F — left index anchor
        XCTAssertEqual(pos?.row,    2)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .index)
    }

    func testHomeRow_J() {
        let pos = layout.position(for: 38)  // J — right index anchor
        XCTAssertEqual(pos?.row,    2)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .index)
    }

    func testHomeRow_Return() {
        let pos = layout.position(for: 36)  // Return
        XCTAssertEqual(pos?.row,    2)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    // MARK: - Top alpha row (row 1)

    func testTopAlpha_E() {
        let pos = layout.position(for: 14)  // E
        XCTAssertEqual(pos?.row,    1)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .middle)
    }

    func testTopAlpha_Y() {
        let pos = layout.position(for: 16)  // Y — right index
        XCTAssertEqual(pos?.row,    1)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .index)
    }

    // MARK: - Number row (row 0)

    func testNumberRow_1() {
        let pos = layout.position(for: 18)  // 1 — left pinky
        XCTAssertEqual(pos?.row,    0)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    func testNumberRow_5() {
        let pos = layout.position(for: 23)  // 5 — left index stretch
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .index)
    }

    func testNumberRow_6() {
        let pos = layout.position(for: 22)  // 6 — right index
        XCTAssertEqual(pos?.row,    0)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .index)
    }

    func testNumberRow_Delete() {
        let pos = layout.position(for: 51)  // Delete
        XCTAssertEqual(pos?.row,    0)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    // MARK: - Modifier keys (row 4, thumb row)

    func testLeftCmd() {
        let pos = layout.position(for: 55)  // Left Cmd
        XCTAssertEqual(pos?.row,    4)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .thumb)
    }

    func testRightCmd() {
        let pos = layout.position(for: 54)  // Right Cmd
        XCTAssertEqual(pos?.row,    4)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .thumb)
    }

    func testLeftOption() {
        let pos = layout.position(for: 58)  // Left Option
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .thumb)
    }

    func testSpace() {
        let pos = layout.position(for: 49)  // Space
        XCTAssertEqual(pos?.row,    4)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .thumb)
    }

    func testLeftShift() {
        let pos = layout.position(for: 56)  // Left Shift
        XCTAssertEqual(pos?.row,    3)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    func testRightShift() {
        let pos = layout.position(for: 60)  // Right Shift
        XCTAssertEqual(pos?.row,    3)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    func testLeftCtrl() {
        let pos = layout.position(for: 59)  // Left Ctrl
        XCTAssertEqual(pos?.row,    4)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    // MARK: - Arrow keys

    func testArrowLeft() {
        let pos = layout.position(for: 123)  // ←
        XCTAssertEqual(pos?.hand, .right)
        XCTAssertEqual(pos?.finger, .index)
    }

    func testArrowRight() {
        let pos = layout.position(for: 124)  // →
        XCTAssertEqual(pos?.hand, .right)
        XCTAssertEqual(pos?.finger, .ring)
    }

    func testArrowDown() {
        let pos = layout.position(for: 125)  // ↓
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .middle)
    }

    func testArrowUp() {
        let pos = layout.position(for: 126)  // ↑ — shares row 2, col 13
        XCTAssertEqual(pos?.row,  2)
        XCTAssertEqual(pos?.hand, .right)
    }

    // MARK: - Function key row (row 5)

    func testF1() {
        let pos = layout.position(for: 122)  // F1
        XCTAssertEqual(pos?.row,    5)
        XCTAssertEqual(pos?.hand,   .left)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    func testF6() {
        let pos = layout.position(for: 97)  // F6
        XCTAssertEqual(pos?.row,    5)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .index)
    }

    func testF12() {
        let pos = layout.position(for: 111)  // F12
        XCTAssertEqual(pos?.row,    5)
        XCTAssertEqual(pos?.hand,   .right)
        XCTAssertEqual(pos?.finger, .pinky)
    }

    // MARK: - Hand symmetry: left-side alpha keys → left hand

    func testLeftAlphaKeysAreLeftHand() {
        // a s d f g (home row left)
        let leftCodes: [CGKeyCode] = [0, 1, 2, 3, 5]
        for code in leftCodes {
            XCTAssertEqual(layout.position(for: code)?.hand, .left,
                           "Key code \(code) expected left hand")
        }
    }

    func testRightAlphaKeysAreRightHand() {
        // h j k l ; ' (home row right)
        let rightCodes: [CGKeyCode] = [4, 38, 40, 37, 41, 39]
        for code in rightCodes {
            XCTAssertEqual(layout.position(for: code)?.hand, .right,
                           "Key code \(code) expected right hand")
        }
    }

    // MARK: - Column ordering within home row

    func testHomeRowLeftColumnsAscending() {
        // CapsLock(col0) A(col1) S(col2) D(col3) F(col4) G(col5) — must be strictly ascending
        let codes: [CGKeyCode] = [57, 0, 1, 2, 3, 5]
        let cols = codes.compactMap { layout.position(for: $0)?.column }
        XCTAssertEqual(cols.count, 6)
        XCTAssertEqual(cols, cols.sorted(), "Left home-row columns should be in ascending order")
    }

    func testHomeRowRightColumnsAscending() {
        // H(col6) J(col7) K(col8) L(col9) ;(col10) '(col11) Return(col12)
        let codes: [CGKeyCode] = [4, 38, 40, 37, 41, 39, 36]
        let cols = codes.compactMap { layout.position(for: $0)?.column }
        XCTAssertEqual(cols.count, 7)
        XCTAssertEqual(cols, cols.sorted(), "Right home-row columns should be in ascending order")
    }

    // MARK: - hand(for keyName:) — ANSILayout

    func testHandForName_leftLetter() {
        XCTAssertEqual(layout.hand(for: "a"), .left)
        XCTAssertEqual(layout.hand(for: "f"), .left)
        XCTAssertEqual(layout.hand(for: "t"), .left)
    }

    func testHandForName_rightLetter() {
        XCTAssertEqual(layout.hand(for: "j"), .right)
        XCTAssertEqual(layout.hand(for: "y"), .right)
        XCTAssertEqual(layout.hand(for: "m"), .right)
    }

    func testHandForName_leftModifiers() {
        XCTAssertEqual(layout.hand(for: "⌘Cmd"),    .left)
        XCTAssertEqual(layout.hand(for: "⇧Shift"),  .left)
        XCTAssertEqual(layout.hand(for: "⌥Option"), .left)
        XCTAssertEqual(layout.hand(for: "⌃Ctrl"),   .left)
        XCTAssertEqual(layout.hand(for: "Space"),    .left)
    }

    func testHandForName_rightNamedKeys() {
        XCTAssertEqual(layout.hand(for: "Return"),   .right)
        XCTAssertEqual(layout.hand(for: "Delete"),   .right)
        XCTAssertEqual(layout.hand(for: "⌦FwdDel"), .right)
    }

    func testHandForName_arrows() {
        XCTAssertEqual(layout.hand(for: "←"), .right)
        XCTAssertEqual(layout.hand(for: "→"), .right)
        XCTAssertEqual(layout.hand(for: "↑"), .right)
        XCTAssertEqual(layout.hand(for: "↓"), .right)
    }

    func testHandForName_functionKeys() {
        XCTAssertEqual(layout.hand(for: "F1"), .left)
        XCTAssertEqual(layout.hand(for: "F5"), .left)
        XCTAssertEqual(layout.hand(for: "F6"), .right)
        XCTAssertEqual(layout.hand(for: "F12"), .right)
    }

    func testHandForName_unknownReturnsNil() {
        // Mouse events are not keyboard keys
        XCTAssertNil(layout.hand(for: "🖱Left"))
        XCTAssertNil(layout.hand(for: "🖱Right"))
        XCTAssertNil(layout.hand(for: "unknown"))
    }

    func testHandForName_keyCodeFallback() {
        // "Key(60)" = Right Shift (not in KeyboardMonitor's named map)
        XCTAssertEqual(layout.hand(for: "Key(60)"), .right)
        // "Key(54)" = Right Cmd
        XCTAssertEqual(layout.hand(for: "Key(54)"), .right)
        // "Key(62)" = Right Ctrl
        XCTAssertEqual(layout.hand(for: "Key(62)"), .right)
    }

    // MARK: - SplitKeyboardConfig

    func testSplitConfig_standardSplitName() {
        XCTAssertEqual(SplitKeyboardConfig.standardSplit.name, "Standard Split")
    }

    func testSplitConfig_standardSplit_leftKeys() {
        let config = SplitKeyboardConfig.standardSplit
        XCTAssertEqual(config.hand(for: "a"), .left)
        XCTAssertEqual(config.hand(for: "t"), .left)
        XCTAssertEqual(config.hand(for: "⌘Cmd"), .left)
        XCTAssertEqual(config.hand(for: "Space"), .left)
    }

    func testSplitConfig_standardSplit_rightKeys() {
        let config = SplitKeyboardConfig.standardSplit
        XCTAssertEqual(config.hand(for: "j"), .right)
        XCTAssertEqual(config.hand(for: "y"), .right)
        XCTAssertEqual(config.hand(for: "Return"), .right)
    }

    func testSplitConfig_standardSplit_mouseIsNil() {
        XCTAssertNil(SplitKeyboardConfig.standardSplit.hand(for: "🖱Left"))
    }

    func testSplitConfig_customConfig() {
        // User who types "b" with right hand
        var config = SplitKeyboardConfig.standardSplit
        var left  = config.leftKeys
        var right = config.rightKeys
        left.remove("b")
        right.insert("b")
        config = SplitKeyboardConfig(name: "Custom", leftKeys: left, rightKeys: right)

        XCTAssertEqual(config.hand(for: "b"), .right)
        XCTAssertEqual(config.hand(for: "v"), .left)  // unchanged
    }

    // MARK: - LayoutRegistry

    func testRegistryDefaultIsANSI() {
        XCTAssertEqual(LayoutRegistry.shared.current.name, "ANSI")
    }

    func testRegistryAcceptsCustomLayout() {
        struct MockLayout: KeyboardLayout {
            let name = "Mock"
            func position(for keyCode: CGKeyCode) -> KeyPosition? { nil }
            func hand(for keyName: String) -> Hand? { nil }
            func finger(for keyName: String) -> Finger? { nil }
        }
        LayoutRegistry.shared.activeProfile = ErgonomicProfile(name: "Mocking", layout: MockLayout())
        XCTAssertEqual(LayoutRegistry.shared.current.name, "Mock")
        // Restore to default
        LayoutRegistry.shared.activeProfile = .standard
        XCTAssertEqual(LayoutRegistry.shared.current.name, "ANSI")
    }

    func testRegistry_noSplitConfig_usesLayout() {
        LayoutRegistry.shared.activeProfile = .standard
        XCTAssertEqual(LayoutRegistry.shared.hand(for: "a"), .left)
        XCTAssertEqual(LayoutRegistry.shared.hand(for: "j"), .right)
    }

    func testRegistry_withSplitConfig_overridesLayout() {
        // Config that flips "b" to right hand
        let config = SplitKeyboardConfig(
            name: "Test",
            leftKeys:  ["a", "s", "d", "f", "g"],
            rightKeys: ["h", "j", "k", "l", "b"]
        )
        LayoutRegistry.shared.activeProfile = ErgonomicProfile(name: "Test Split", splitConfig: config)

        XCTAssertEqual(LayoutRegistry.shared.hand(for: "b"), .right)  // overridden by splitConfig
        XCTAssertEqual(LayoutRegistry.shared.hand(for: "a"), .left)   // in splitConfig
        // "z" is not in splitConfig → falls back to ANSILayout which says .left
        XCTAssertEqual(LayoutRegistry.shared.hand(for: "z"), .left)

        // Cleanup
        LayoutRegistry.shared.activeProfile = .standard
    }

    // MARK: - finger(for keyName:) — ANSILayout

    func testFingerForName_leftPinky() {
        // a, q, z share the pinky (left side)
        XCTAssertEqual(layout.finger(for: "a"),       .pinky)
        XCTAssertEqual(layout.finger(for: "q"),       .pinky)
        XCTAssertEqual(layout.finger(for: "z"),       .pinky)
        XCTAssertEqual(layout.finger(for: "Tab"),     .pinky)
        XCTAssertEqual(layout.finger(for: "⇧Shift"),  .pinky)
        XCTAssertEqual(layout.finger(for: "1"),       .pinky)
    }

    func testFingerForName_leftRing() {
        XCTAssertEqual(layout.finger(for: "s"), .ring)
        XCTAssertEqual(layout.finger(for: "w"), .ring)
        XCTAssertEqual(layout.finger(for: "x"), .ring)
        XCTAssertEqual(layout.finger(for: "2"), .ring)
    }

    func testFingerForName_leftMiddle() {
        XCTAssertEqual(layout.finger(for: "d"), .middle)
        XCTAssertEqual(layout.finger(for: "e"), .middle)
        XCTAssertEqual(layout.finger(for: "c"), .middle)
        XCTAssertEqual(layout.finger(for: "3"), .middle)
    }

    func testFingerForName_leftIndex() {
        // f r v are primary; t g b are the stretch keys
        XCTAssertEqual(layout.finger(for: "f"), .index)
        XCTAssertEqual(layout.finger(for: "r"), .index)
        XCTAssertEqual(layout.finger(for: "t"), .index)
        XCTAssertEqual(layout.finger(for: "g"), .index)
        XCTAssertEqual(layout.finger(for: "b"), .index)
        XCTAssertEqual(layout.finger(for: "4"), .index)
        XCTAssertEqual(layout.finger(for: "5"), .index)
    }

    func testFingerForName_thumb() {
        XCTAssertEqual(layout.finger(for: "Space"),    .thumb)
        XCTAssertEqual(layout.finger(for: "⌘Cmd"),    .thumb)
        XCTAssertEqual(layout.finger(for: "⌥Option"), .thumb)
    }

    func testFingerForName_rightIndex() {
        XCTAssertEqual(layout.finger(for: "j"), .index)
        XCTAssertEqual(layout.finger(for: "u"), .index)
        XCTAssertEqual(layout.finger(for: "y"), .index)
        XCTAssertEqual(layout.finger(for: "h"), .index)
        XCTAssertEqual(layout.finger(for: "n"), .index)
        XCTAssertEqual(layout.finger(for: "m"), .index)
        XCTAssertEqual(layout.finger(for: "6"), .index)
        XCTAssertEqual(layout.finger(for: "7"), .index)
    }

    func testFingerForName_rightMiddle() {
        XCTAssertEqual(layout.finger(for: "k"), .middle)
        XCTAssertEqual(layout.finger(for: "i"), .middle)
        XCTAssertEqual(layout.finger(for: ","), .middle)
        XCTAssertEqual(layout.finger(for: "8"), .middle)
        XCTAssertEqual(layout.finger(for: "↓"), .middle)
        XCTAssertEqual(layout.finger(for: "↑"), .middle)
    }

    func testFingerForName_rightRing() {
        XCTAssertEqual(layout.finger(for: "l"), .ring)
        XCTAssertEqual(layout.finger(for: "o"), .ring)
        XCTAssertEqual(layout.finger(for: "."), .ring)
        XCTAssertEqual(layout.finger(for: "9"), .ring)
        XCTAssertEqual(layout.finger(for: "→"), .ring)
    }

    func testFingerForName_rightPinky() {
        XCTAssertEqual(layout.finger(for: ";"),        .pinky)
        XCTAssertEqual(layout.finger(for: "Return"),   .pinky)
        XCTAssertEqual(layout.finger(for: "Delete"),   .pinky)
        XCTAssertEqual(layout.finger(for: "p"),        .pinky)
        XCTAssertEqual(layout.finger(for: "0"),        .pinky)
        XCTAssertEqual(layout.finger(for: "←"),        .pinky)
    }

    func testFingerForName_functionKeys() {
        XCTAssertEqual(layout.finger(for: "F1"),  .pinky)
        XCTAssertEqual(layout.finger(for: "F2"),  .ring)
        XCTAssertEqual(layout.finger(for: "F3"),  .middle)
        XCTAssertEqual(layout.finger(for: "F4"),  .index)
        XCTAssertEqual(layout.finger(for: "F5"),  .index)
        XCTAssertEqual(layout.finger(for: "F6"),  .index)
        XCTAssertEqual(layout.finger(for: "F12"), .pinky)
    }

    func testFingerForName_unknownReturnsNil() {
        XCTAssertNil(layout.finger(for: "🖱Left"))
        XCTAssertNil(layout.finger(for: "unknown"))
    }

    func testFingerForName_keyCodeFallback() {
        // "Key(60)" = Right Shift → pinky
        XCTAssertEqual(layout.finger(for: "Key(60)"), .pinky)
        // "Key(54)" = Right Cmd → thumb
        XCTAssertEqual(layout.finger(for: "Key(54)"), .thumb)
    }

    func testFingerAndHand_combination() {
        // Verify that hand + finger together give the full picture
        XCTAssertEqual(layout.hand(for: "j"),   .right)
        XCTAssertEqual(layout.finger(for: "j"), .index)  // right index

        XCTAssertEqual(layout.hand(for: "f"),   .left)
        XCTAssertEqual(layout.finger(for: "f"), .index)  // left index

        XCTAssertEqual(layout.hand(for: "Space"),   .left)
        XCTAssertEqual(layout.finger(for: "Space"), .thumb)  // left thumb
    }

    func testRegistry_splitConfig_takesPreferenceOverLayout() {
        // splitConfig says "Space" is right — overrides ANSILayout's .left
        let config = SplitKeyboardConfig(name: "Flip", leftKeys: [], rightKeys: ["Space"])
        LayoutRegistry.shared.activeProfile = ErgonomicProfile(name: "Flip", splitConfig: config)
        XCTAssertEqual(LayoutRegistry.shared.hand(for: "Space"), .right)
        LayoutRegistry.shared.activeProfile = .standard
    }
}
