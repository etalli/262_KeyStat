import SwiftUI
import Combine

// MARK: - ChartTheme

enum ChartTheme: String, CaseIterable, Identifiable {
    case blue   = "blue"
    case teal   = "teal"
    case purple = "purple"
    case orange = "orange"
    case green  = "green"
    case pink   = "pink"

    var id: String { rawValue }

    var displayName: String {
        L10n.shared.chartThemeDisplayName(self)
    }

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .teal:   return .teal
        case .purple: return .purple
        case .orange: return .orange
        case .green:  return .green
        case .pink:   return .pink
        }
    }

    /// Hue value (0–1) used for the keyboard heatmap gradient.
    var heatmapBaseHue: Double {
        switch self {
        case .blue:   return 0.60
        case .teal:   return 0.50
        case .purple: return 0.75
        case .orange: return 0.08
        case .green:  return 0.35
        case .pink:   return 0.85
        }
    }
}

// MARK: - ThemeStore

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var current: ChartTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "chartTheme") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "chartTheme") ?? ""
        current = ChartTheme(rawValue: saved) ?? .blue
    }

    var accentColor: Color { current.color }
}
