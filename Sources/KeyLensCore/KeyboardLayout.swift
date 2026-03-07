import CoreGraphics

// MARK: - Hand / Finger

/// Which hand is used to press a key.
public enum Hand: String, Equatable, CaseIterable {
    case left
    case right
}

/// Which finger is used to press a key (standard touch-typing assignment).
public enum Finger: String, Equatable, CaseIterable {
    case pinky
    case ring
    case middle
    case index
    case thumb
}

// MARK: - KeyPosition

/// Physical position and ergonomic metadata for a single key.
///
/// Row conventions (top-to-bottom):
///   5 = function key row  (F1–F12)
///   0 = number row        (Esc  `  1  2  3  4  5  6  7  8  9  0  -  =  Delete)
///   1 = top alpha row     (Tab  Q  W  E  R  T  Y  U  I  O  P  [  ]  \)
///   2 = home row          (CapsLock  A  S  D  F  G  H  J  K  L  ;  '  Return)
///   3 = bottom row        (Shift  Z  X  C  V  B  N  M  ,  .  /  Shift)
///   4 = thumb / space row (Ctrl  Option  Cmd  Space  Cmd  Option  Ctrl)
///
/// Column 0 = leftmost key in the row.
public struct KeyPosition: Equatable {
    public let row: Int
    public let column: Int
    public let hand: Hand
    public let finger: Finger

    public init(row: Int, column: Int, hand: Hand, finger: Finger) {
        self.row = row; self.column = column; self.hand = hand; self.finger = finger
    }
}

// MARK: - Protocol

/// Abstracts a physical keyboard layout, mapping keys to logical positions and hands.
///
/// CGKeyCode is used as the source of truth for physical location because it is a
/// hardware scan code — it identifies which physical key was pressed regardless of
/// the software input method (ANSI, JIS, Dvorak, custom remapping, etc.).
///
/// Key name strings (e.g. "a", "Space", "⌘Cmd") match the values stored in
/// KeyCountStore, enabling ergonomic analysis without changing the data layer.
public protocol KeyboardLayout {
    /// Human-readable layout name (e.g. "ANSI", "JIS").
    var name: String { get }

    /// Returns the ergonomic position for a hardware key code, or nil if not mapped.
    func position(for keyCode: CGKeyCode) -> KeyPosition?

    /// Returns the hand assignment for a key name string, or nil if not mapped.
    /// Key names must match the strings produced by KeyboardMonitor (e.g. "a", "Space", "⌘Cmd").
    func hand(for keyName: String) -> Hand?

    /// Returns the finger assignment for a key name string, or nil if not mapped.
    /// The returned Finger is hand-agnostic; combine with hand(for:) for full ergonomic data.
    /// e.g. finger(for: "j") → .index, hand(for: "j") → .right  ⟹  right index
    func finger(for keyName: String) -> Finger?

    /// Returns the full ergonomic position for a key name string, or nil if not mapped.
    /// Used by SameFingerPenalty to determine the physical grid distance between two keys.
    /// キー名からグリッド座標・手・指を含む KeyPosition を返す。同指ペナルティ計算で使用。
    func position(for keyName: String) -> KeyPosition?
}

// Default implementation — returns nil for layouts that do not provide a name→position table.
// 名前→位置テーブルを持たないレイアウトのデフォルト実装。
extension KeyboardLayout {
    public func position(for keyName: String) -> KeyPosition? { nil }
}

// MARK: - ANSI Layout

/// Standard US ANSI keyboard layout.
///
/// Finger assignments follow conventional touch-typing standards.
/// Modifier keys (Cmd, Shift, Ctrl, Option) are included because they
/// contribute to finger load and ergonomic analysis.
public struct ANSILayout: KeyboardLayout, Equatable {
    public let name = "ANSI"
    public init() {}

    public func position(for keyCode: CGKeyCode) -> KeyPosition? {
        ANSILayout.table[keyCode]
    }

    public func hand(for keyName: String) -> Hand? {
        // Direct string lookup
        if let hand = ANSILayout.handTable[keyName] { return hand }

        // Fallback: "Key(N)" format for keys not in KeyboardMonitor's named map
        // (e.g. "Key(60)" = Right Shift, "Key(54)" = Right Cmd)
        if keyName.hasPrefix("Key("), keyName.hasSuffix(")"),
           let code = UInt16(keyName.dropFirst(4).dropLast()) {
            return ANSILayout.table[code]?.hand
        }

        return nil
    }

    public func finger(for keyName: String) -> Finger? {
        // Direct string lookup
        if let finger = ANSILayout.fingerTable[keyName] { return finger }

        // Fallback: "Key(N)" format (e.g. "Key(60)" = Right Shift → pinky)
        if keyName.hasPrefix("Key("), keyName.hasSuffix(")"),
           let code = UInt16(keyName.dropFirst(4).dropLast()) {
            return ANSILayout.table[code]?.finger
        }

        return nil
    }

    public func position(for keyName: String) -> KeyPosition? {
        ANSILayout.positionNameTable[keyName]
    }

    // MARK: - Static lookup: CGKeyCode -> KeyPosition
    // Derived from the CoreGraphics key code values observed on standard Apple keyboards.
    public static let table: [CGKeyCode: KeyPosition] = {
        func p(_ row: Int, _ col: Int, _ hand: Hand, _ finger: Finger) -> KeyPosition {
            KeyPosition(row: row, column: col, hand: hand, finger: finger)
        }

        return [
            // MARK: Row 0 — Number / Escape row
            // Esc ` 1 2 3 4 5 | 6 7 8 9 0 - = Delete
            53:  p(0,  0, .left,  .pinky),  // Escape
            50:  p(0,  1, .left,  .pinky),  // `
            18:  p(0,  2, .left,  .pinky),  // 1
            19:  p(0,  3, .left,  .ring),   // 2
            20:  p(0,  4, .left,  .middle), // 3
            21:  p(0,  5, .left,  .index),  // 4
            23:  p(0,  6, .left,  .index),  // 5
            22:  p(0,  7, .right, .index),  // 6
            26:  p(0,  8, .right, .index),  // 7
            28:  p(0,  9, .right, .middle), // 8
            25:  p(0, 10, .right, .ring),   // 9
            29:  p(0, 11, .right, .pinky),  // 0
            27:  p(0, 12, .right, .pinky),  // -
            24:  p(0, 13, .right, .pinky),  // =
            51:  p(0, 14, .right, .pinky),  // Delete
            117: p(0, 15, .right, .pinky),  // ⌦ Forward Delete

            // MARK: Row 1 — Top alpha row
            // Tab Q W E R T | Y U I O P [ ] \
            48:  p(1,  0, .left,  .pinky),  // Tab
            12:  p(1,  1, .left,  .pinky),  // Q
            13:  p(1,  2, .left,  .ring),   // W
            14:  p(1,  3, .left,  .middle), // E
            15:  p(1,  4, .left,  .index),  // R
            17:  p(1,  5, .left,  .index),  // T
            16:  p(1,  6, .right, .index),  // Y
            32:  p(1,  7, .right, .index),  // U
            34:  p(1,  8, .right, .middle), // I
            31:  p(1,  9, .right, .ring),   // O
            35:  p(1, 10, .right, .pinky),  // P
            33:  p(1, 11, .right, .pinky),  // [
            30:  p(1, 12, .right, .pinky),  // ]
            42:  p(1, 13, .right, .pinky),  // \

            // MARK: Row 2 — Home row
            // CapsLock A S D F G | H J K L ; ' Return
            57:  p(2,  0, .left,  .pinky),  // CapsLock
             0:  p(2,  1, .left,  .pinky),  // A
             1:  p(2,  2, .left,  .ring),   // S
             2:  p(2,  3, .left,  .middle), // D
             3:  p(2,  4, .left,  .index),  // F
             5:  p(2,  5, .left,  .index),  // G
             4:  p(2,  6, .right, .index),  // H
            38:  p(2,  7, .right, .index),  // J
            40:  p(2,  8, .right, .middle), // K
            37:  p(2,  9, .right, .ring),   // L
            41:  p(2, 10, .right, .pinky),  // ;
            39:  p(2, 11, .right, .pinky),  // '
            36:  p(2, 12, .right, .pinky),  // Return
            126: p(2, 13, .right, .middle), // ↑ (above ↓ in arrow cluster)

            // MARK: Row 3 — Bottom row
            // Shift Z X C V B | N M , . / Shift  [← ↓ →]
            56:  p(3,  0, .left,  .pinky),  // Left Shift
             6:  p(3,  1, .left,  .pinky),  // Z
             7:  p(3,  2, .left,  .ring),   // X
             8:  p(3,  3, .left,  .middle), // C
             9:  p(3,  4, .left,  .index),  // V
            11:  p(3,  5, .left,  .index),  // B
            45:  p(3,  6, .right, .index),  // N
            46:  p(3,  7, .right, .index),  // M
            43:  p(3,  8, .right, .middle), // ,
            47:  p(3,  9, .right, .ring),   // .
            44:  p(3, 10, .right, .pinky),  // /
            60:  p(3, 11, .right, .pinky),  // Right Shift
            123: p(3, 12, .right, .index),  // ←
            125: p(3, 13, .right, .middle), // ↓
            124: p(3, 14, .right, .ring),   // →

            // MARK: Row 4 — Thumb / space row
            // Ctrl Option Cmd Space | Cmd Option Ctrl  [Enter(Num)]
            59:  p(4,  0, .left,  .pinky),  // Left Ctrl
            58:  p(4,  1, .left,  .thumb),  // Left Option
            55:  p(4,  2, .left,  .thumb),  // Left Cmd
            49:  p(4,  3, .left,  .thumb),  // Space
            54:  p(4,  4, .right, .thumb),  // Right Cmd
            61:  p(4,  5, .right, .thumb),  // Right Option
            62:  p(4,  6, .right, .pinky),  // Right Ctrl
            76:  p(4,  7, .right, .pinky),  // Enter (Numpad)

            // MARK: Row 5 — Function key row
            // F1 F2 F3 F4 F5 | F6 F7 F8 F9 F10 F11 F12
            122: p(5,  1, .left,  .pinky),  // F1
            120: p(5,  2, .left,  .ring),   // F2
             99: p(5,  3, .left,  .middle), // F3
            118: p(5,  4, .left,  .index),  // F4
             96: p(5,  5, .left,  .index),  // F5
             97: p(5,  6, .right, .index),  // F6
             98: p(5,  7, .right, .index),  // F7
            100: p(5,  8, .right, .middle), // F8
            101: p(5,  9, .right, .ring),   // F9
            109: p(5, 10, .right, .pinky),  // F10
            103: p(5, 11, .right, .pinky),  // F11
            111: p(5, 12, .right, .pinky),  // F12
        ]
    }()

    // MARK: - Static lookup: key name String -> Hand
    // Key name strings match the values produced by KeyboardMonitor.keyName(for:)
    // and stored in KeyCountStore.
    public static let handTable: [String: Hand] = {
        var t: [String: Hand] = [:]

        // Left hand — alpha
        for k in ["q","w","e","r","t","a","s","d","f","g","z","x","c","v","b"] { t[k] = .left }
        // Right hand — alpha
        for k in ["y","u","i","o","p","h","j","k","l","n","m"]                 { t[k] = .right }

        // Left hand — number row
        for k in ["`","1","2","3","4","5"] { t[k] = .left }
        // Right hand — number row
        for k in ["6","7","8","9","0","-","="] { t[k] = .right }

        // Right hand — symbol keys
        for k in ["[","]","\\",";","'",",",".","/"] { t[k] = .right }

        // Left hand — named keys
        for k in ["Escape","Tab","CapsLock","⇧Shift","⌃Ctrl","⌥Option","⌘Cmd","Space"] { t[k] = .left }
        // Right hand — named keys
        for k in ["Return","Delete","⌦FwdDel","Enter(Num)"] { t[k] = .right }

        // Right hand — arrows
        for k in ["←","→","↑","↓"] { t[k] = .right }

        // Left hand — function keys
        for k in ["F1","F2","F3","F4","F5"] { t[k] = .left }
        // Right hand — function keys
        for k in ["F6","F7","F8","F9","F10","F11","F12"] { t[k] = .right }

        return t
    }()

    // MARK: - Static lookup: key name String -> Finger
    // Hand-agnostic: combine with handTable to get the full assignment.
    // e.g. fingerTable["j"] = .index, handTable["j"] = .right  ⟹  right index finger
    public static let fingerTable: [String: Finger] = {
        var t: [String: Finger] = [:]

        // Pinky keys (left & right — same finger type, hand determined by handTable)
        // Left pinky: Esc ` 1  Tab Q A Z  CapsLock ⇧Shift ⌃Ctrl  F1
        for k in ["Escape","`","1","Tab","q","a","z","CapsLock","⇧Shift","⌃Ctrl","F1"] { t[k] = .pinky }
        // Right pinky: 0 - = Delete ⌦FwdDel  P [ ] \  ; '  Return  / ←  Enter(Num)  F10 F11 F12
        for k in ["0","-","=","Delete","⌦FwdDel",
                  "p","[","]","\\",";","'","Return","/","←","Enter(Num)",
                  "F10","F11","F12"] { t[k] = .pinky }

        // Ring keys
        // Left ring: 2  W S X  F2
        for k in ["2","w","s","x","F2"] { t[k] = .ring }
        // Right ring: 9  O L .  →  F9
        for k in ["9","o","l",".","→","F9"] { t[k] = .ring }

        // Middle keys
        // Left middle: 3  E D C  F3
        for k in ["3","e","d","c","F3"] { t[k] = .middle }
        // Right middle: 8  I K ,  ↓ ↑  F8
        for k in ["8","i","k",",","↓","↑","F8"] { t[k] = .middle }

        // Index keys
        // Left index: 4 5  R T F G V B  F4 F5
        for k in ["4","5","r","t","f","g","v","b","F4","F5"] { t[k] = .index }
        // Right index: 6 7  Y U H J N M  F6 F7
        for k in ["6","7","y","u","h","j","n","m","F6","F7"] { t[k] = .index }

        // Thumb keys
        // Left thumb: Space ⌘Cmd ⌥Option
        for k in ["Space","⌘Cmd","⌥Option"] { t[k] = .thumb }
        // Right thumb: Right Cmd / Option appear as "Key(N)" — resolved via table fallback

        return t
    }()

    // MARK: - Static lookup: key name String -> KeyPosition
    // Derived from nameToKeyCode (below) combined with the existing table.
    // This enables distance-based ergonomic analysis (SameFingerPenalty) using key name strings.
    // キー名→位置のルックアップ。同指ペナルティの距離計算に使用する。
    public static let positionNameTable: [String: KeyPosition] =
        nameToKeyCode.compactMapValues { table[$0] }

    // Maps KeyboardMonitor key name strings to their CGKeyCode.
    // Key names match the values in handTable / fingerTable.
    private static let nameToKeyCode: [String: CGKeyCode] = [
        // MARK: Row 0 — Number / Escape row
        "Escape": 53, "`": 50,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        "-": 27, "=": 24, "Delete": 51, "⌦FwdDel": 117,

        // MARK: Row 1 — Top alpha row
        "Tab": 48,
        "q": 12, "w": 13, "e": 14, "r": 15, "t": 17,
        "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
        "[": 33, "]": 30, "\\": 42,

        // MARK: Row 2 — Home row
        "CapsLock": 57,
        "a": 0, "s": 1, "d": 2, "f": 3, "g": 5,
        "h": 4, "j": 38, "k": 40, "l": 37,
        ";": 41, "'": 39, "Return": 36, "↑": 126,

        // MARK: Row 3 — Bottom row
        "⇧Shift": 56,
        "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "n": 45, "m": 46, ",": 43, ".": 47, "/": 44,
        "←": 123, "↓": 125, "→": 124,

        // MARK: Row 4 — Thumb / space row
        "⌃Ctrl": 59, "⌥Option": 58, "⌘Cmd": 55, "Space": 49,
        "Enter(Num)": 76,

        // MARK: Row 5 — Function key row
        "F1": 122, "F2": 120, "F3": 99, "F4": 118, "F5": 96,
        "F6": 97,  "F7": 98,  "F8": 100, "F9": 101,
        "F10": 109, "F11": 103, "F12": 111,
    ]
}

// MARK: - SplitKeyboardConfig

/// Represents the physical left/right key assignment for a split keyboard.
///
/// Split keyboard users can override the default ANSI hand assignment by setting
/// a SplitKeyboardConfig in LayoutRegistry. Key names must match the strings
/// produced by KeyboardMonitor (e.g. "a", "Space", "⌘Cmd").
///
/// Use `standardSplit` for typical center-split keyboards (same split point as
/// ANSI touch-typing convention). For non-standard splits, initialize directly
/// with custom leftKeys / rightKeys sets.
public struct SplitKeyboardConfig: Equatable {
    public let name: String
    public let leftKeys: Set<String>
    public let rightKeys: Set<String>

    public init(name: String, leftKeys: Set<String>, rightKeys: Set<String>) {
        self.name = name; self.leftKeys = leftKeys; self.rightKeys = rightKeys
    }

    public func hand(for keyName: String) -> Hand? {
        if leftKeys.contains(keyName)  { return .left }
        if rightKeys.contains(keyName) { return .right }
        return nil
    }

    /// Standard center-split preset: same hand boundary as the ANSI touch-typing convention.
    /// Suitable for most symmetric split keyboards (e.g. 60%, 65%, ortholinear splits).
    public static var standardSplit: SplitKeyboardConfig {
        let left  = Set(ANSILayout.handTable.filter { $0.value == .left  }.keys)
        let right = Set(ANSILayout.handTable.filter { $0.value == .right }.keys)
        return SplitKeyboardConfig(name: "Standard Split", leftKeys: left, rightKeys: right)
    }
}

// MARK: - LayoutRegistry

/// Holds the active keyboard layout and optional split configuration.
///
/// Resolution order for `hand(for:)`:
///   1. splitConfig (if set) — for split keyboard users who override hand assignment
///   2. current layout's hand(for:) — default ANSI or custom layout
///
/// Downstream features (hand alternation, thumb imbalance, ergonomic scoring)
/// should call `LayoutRegistry.shared.hand(for:)` rather than querying the
/// layout directly, to respect any split config the user has set.
public final class LayoutRegistry {
    public static let shared = LayoutRegistry()

    public var activeProfile: ErgonomicProfile = .standard
    
    /// Human-readable label for the currently detected keyboard device set.
    /// Uses the connected HID product names when available.
    /// 現在検出されているキーボードデバイス集合の表示ラベル。
    public private(set) var currentDeviceLabel: String = "Unknown Keyboard"
    
    /// Returns the active layout from the current profile.
    public var current: any KeyboardLayout { activeProfile.layout }

    /// Returns the hand for a key name, respecting profile split config if set.
    public func hand(for keyName: String) -> Hand? {
        activeProfile.splitConfig?.hand(for: keyName) ?? activeProfile.layout.hand(for: keyName)
    }

    /// Returns the load weight for the finger assigned to a key name, or nil if the key is unknown.
    /// キー名からその指の負荷重みを返す。未知のキーは nil。
    public func loadWeight(for keyName: String) -> Double? {
        guard let finger = activeProfile.layout.finger(for: keyName) else { return nil }
        return activeProfile.fingerWeights.weight(for: finger)
    }

    // Deprecated properties — kept for backward compatibility if needed, but redirects to activeProfile
    @available(*, deprecated, message: "Use activeProfile.layout instead")
    public var _current: any KeyboardLayout {
        get { activeProfile.layout }
        set { /* No-op or update profile? Better to stick to activeProfile */ }
    }

    /// Active same-finger penalty model. Defaults to exponent = 2.0.
    /// 有効な同指ペナルティモデル。デフォルトは指数 2.0。
    public var sameFingerPenaltyModel: SameFingerPenalty = .default

    /// Returns the ergonomic penalty for a same-finger bigram string (e.g. "f→r"),
    /// or nil if the keys are unknown, not same-finger, or not on the same hand.
    ///
    /// This is the primary integration point with KeyCountStore.bigramCounts:
    /// pass any key from that dictionary directly to compute its penalty.
    ///
    /// キー名ビグラム文字列（例："f→r"）に対する同指ペナルティを返す。
    /// 未知キー・異指・異手の場合は nil。
    public func sameFingerPenalty(for bigram: String) -> Double? {
        let parts = bigram.components(separatedBy: "→")
        guard parts.count == 2 else { return nil }
        let (k1, k2) = (parts[0], parts[1])

        // Both keys must be on the same hand and use the same finger.
        // 同じ手・同じ指でなければ同指ビグラムではない。
        guard let finger1 = activeProfile.layout.finger(for: k1),
              let finger2 = activeProfile.layout.finger(for: k2),
              finger1 == finger2,
              let hand1 = hand(for: k1),
              let hand2 = hand(for: k2),
              hand1 == hand2 else { return nil }

        guard let pos1 = activeProfile.layout.position(for: k1),
              let pos2 = activeProfile.layout.position(for: k2) else { return nil }

        let fw = activeProfile.fingerWeights.weight(for: finger1)
        return sameFingerPenaltyModel.penalty(from: pos1, to: pos2, fingerWeight: fw)
    }

    /// Active alternation reward model. Defaults to baseReward=1.0, threshold=3, multiplier=1.5.
    /// 有効な交互打鍵報酬モデル。デフォルトは基本報酬 1.0、しきい値 3、乗数 1.5。
    public var alternationRewardModel: AlternationReward = .default

    /// Active thumb imbalance detector. Defaults to threshold=0.3.
    /// 有効な親指偏り検出器。デフォルトは閾値 0.3。
    public var thumbImbalanceDetector: ThumbImbalanceDetector = .default

    /// Active thumb efficiency calculator. Defaults to expectedThumbRatio=0.15.
    /// 有効な親指効率計算機。デフォルトは期待比率 0.15。
    public var thumbEfficiencyCalculator: ThumbEfficiencyCalculator = .default

    /// Active high-strain detector. Defaults to minimumTier=.oneRow.
    /// 有効な高負荷シーケンス検出器。デフォルトは最小ティア .oneRow。
    public var highStrainDetector: HighStrainDetector = .default

    /// Active ergonomic score engine. Defaults to Issue #29 weights and thumbEfficiencyMax=2.0.
    /// 有効なエルゴノミクススコアエンジン。デフォルトは Issue #29 重みテーブル。
    public var ergonomicScoreEngine: ErgonomicScoreEngine = .default

    /// Internal designated initialiser. Use `LayoutRegistry.shared` for the global singleton
    /// or `LayoutRegistry.forSimulation(layout:base:)` for isolated evaluation contexts.
    /// シングルトンは `.shared`、シミュレーション用は `forSimulation` を使うこと。
    init() {}

    // MARK: - Simulation factory

    /// Creates an isolated LayoutRegistry configured for layout simulation or testing.
    ///
    /// The returned registry inherits all configuration from `base` but uses the given
    /// `layout` as its active layout. The global singleton is not modified.
    ///
    /// ```swift
    /// let remapped = KeyRelocationSimulator.layout(applying: map, over: ANSILayout())
    /// let simReg   = LayoutRegistry.forSimulation(layout: remapped)
    /// let snapshot = ErgonomicSnapshot.capture(bigramCounts: ..., keyCounts: ..., layout: simReg)
    /// ```
    ///
    /// グローバルシングルトンを変更せず、シミュレーション用の独立したレジストリを返す。
    public static func forSimulation(
        layout: any KeyboardLayout,
        base:   LayoutRegistry = .shared
    ) -> LayoutRegistry {
        let reg = LayoutRegistry()
        reg.activeProfile = ErgonomicProfile(
            name: "Simulation: \(layout.name)",
            layout: layout,
            fingerWeights: base.activeProfile.fingerWeights,
            splitConfig: base.activeProfile.splitConfig
        )
        reg.sameFingerPenaltyModel    = base.sameFingerPenaltyModel
        reg.alternationRewardModel    = base.alternationRewardModel
        reg.thumbImbalanceDetector    = base.thumbImbalanceDetector
        reg.thumbEfficiencyCalculator = base.thumbEfficiencyCalculator
        reg.highStrainDetector        = base.highStrainDetector
        reg.ergonomicScoreEngine      = base.ergonomicScoreEngine
        reg.currentDeviceLabel        = base.currentDeviceLabel
        return reg
    }
    
    // MARK: - Hardware Awareness
    
    /// Normalises the connected device name list into a stable display label.
    /// 接続デバイス名の配列を安定した表示ラベルに正規化する。
    static func resolvedDeviceLabel(for names: [String]) -> String {
        let cleaned = Array(
            Set(
                names
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
        guard !cleaned.isEmpty else { return "Unknown Keyboard" }
        return cleaned.joined(separator: " / ")
    }
    
    /// Updates the active profile based on the detected keyboard hardware names.
    /// 接続中のキーボード名に基づいてアクティブプロファイルを更新する。
    public func applyProfile(forDeviceNames names: [String]) {
        let splitKeywords = ["split", "ergo", "moonlander", "advantage", "corne", "reviung", "pangaea"]
        currentDeviceLabel = Self.resolvedDeviceLabel(for: names)
        
        let detectedSplit = names.contains { name in
            let lower = name.lowercased()
            return splitKeywords.contains { lower.contains($0) }
        }
        
        let newProfile = detectedSplit ? ErgonomicProfile.splitErgo : ErgonomicProfile.standard
        
        if activeProfile != newProfile {
            let devices = names.isEmpty ? "None" : names.joined(separator: ", ")
            print("[LayoutRegistry] Hardware change detected: \(devices)")
            print("[LayoutRegistry] Switching profile to: \(newProfile.name)")
            activeProfile = newProfile
        }
    }
}
