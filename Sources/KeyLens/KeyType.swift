import SwiftUI

/// キー名を分類するための enum
enum KeyType: String, CaseIterable, Hashable {
    case letter   = "letter"
    case number   = "number"
    case arrow    = "arrow"
    case control  = "control"
    case function = "function"
    case mouse    = "mouse"
    case other    = "other"

    var color: Color {
        switch self {
        case .letter:   return Color(hue: 0.13, saturation: 0.85, brightness: 0.95) // 黄
        case .number:   return Color(hue: 0.37, saturation: 0.72, brightness: 0.80) // 緑
        case .arrow:    return Color(hue: 0.60, saturation: 0.72, brightness: 0.96) // 青
        case .control:  return Color(hue: 0.07, saturation: 0.85, brightness: 0.96) // 橙
        case .function: return Color(hue: 0.50, saturation: 0.62, brightness: 0.80) // 青緑
        case .mouse:    return Color(hue: 0.77, saturation: 0.62, brightness: 0.90) // 紫
        case .other:    return Color(white: 0.55)
        }
    }

    var label: String {
        switch self {
        case .letter:   return "Letters"
        case .number:   return "Numbers"
        case .arrow:    return "Arrows"
        case .control:  return "Control"
        case .function: return "Function"
        case .mouse:    return "Mouse"
        case .other:    return "Other"
        }
    }

    /// キー名 → KeyType に分類する
    static func classify(_ key: String) -> KeyType {
        if key.hasPrefix("🖱") { return .mouse }

        if key.count == 1, let scalar = key.unicodeScalars.first {
            let v = scalar.value
            if v >= 97 && v <= 122 { return .letter }  // a–z
            if v >= 48 && v <= 57  { return .number }  // 0–9
        }

        if ["←", "→", "↑", "↓"].contains(key) { return .arrow }

        let controlKeys: Set<String> = [
            "Return", "Tab", "Space", "Delete", "Escape",
            "⌘Cmd", "⇧Shift", "CapsLock", "⌥Option", "⌃Ctrl",
            "Enter(Num)", "⌦FwdDel"
        ]
        if controlKeys.contains(key) { return .control }

        // F1–F12
        if key.count >= 2 && key.hasPrefix("F"), Int(key.dropFirst()) != nil { return .function }

        return .other
    }
}
