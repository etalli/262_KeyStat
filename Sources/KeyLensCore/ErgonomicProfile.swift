import Foundation

/// A collection of ergonomic parameters and layout configuration for a specific keyboard.
/// 特定のキーボードに対するエルゴノミクスパラメータとレイアウト設定の集合。
public struct ErgonomicProfile: Equatable {
    /// Human-readable name of the profile.
    public let name: String
    
    /// The physical layout to use for mapping key names to positions.
    public let layout: any KeyboardLayout
    
    /// Finger capability weights (natural strength/mobility).
    public let fingerWeights: FingerLoadWeight
    
    /// Optional hand mapping overrides (for split keyboards).
    public let splitConfig: SplitKeyboardConfig?
    
    public init(
        name: String,
        layout: any KeyboardLayout = ANSILayout(),
        fingerWeights: FingerLoadWeight = .default,
        splitConfig: SplitKeyboardConfig? = nil
    ) {
        self.name = name
        self.layout = layout
        self.fingerWeights = fingerWeights
        self.splitConfig = splitConfig
    }
    
    public static func == (lhs: ErgonomicProfile, rhs: ErgonomicProfile) -> Bool {
        return lhs.name == rhs.name &&
               lhs.fingerWeights == rhs.fingerWeights &&
               lhs.splitConfig == rhs.splitConfig &&
               lhs.layout.name == rhs.layout.name
    }
}

// MARK: - Presets

extension ErgonomicProfile {
    /// Default profile for standard non-split laptops and desktop keyboards.
    /// 標準的なラップトップや非分割キーボード用のデフォルトプロファイル。
    public static let standard = ErgonomicProfile(
        name: "Standard"
    )
    
    /// Optimized profile for split ergonomic keyboards with thumb clusters.
    /// 親指クラスターを持つ分割エルゴノミクスキーボード用に最適化されたプロファイル。
    public static let splitErgo = ErgonomicProfile(
        name: "Split Ergonomic",
        fingerWeights: FingerLoadWeight(weights: [
            .index:  1.0,
            .middle: 0.9,
            .thumb:  1.0, // High capability thumb weight for ergo keyboards
            .ring:   0.6,
            .pinky:  0.5,
        ]),
        splitConfig: .standardSplit
    )
}
