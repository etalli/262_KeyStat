import Foundation
import Combine

// MARK: - MenuWidget

/// Represents a toggleable stat widget shown in the menu bar popover.
/// メニューバーポップオーバーに表示する統計ウィジェットを定義する列挙型。
enum MenuWidget: String, CaseIterable, Identifiable {
    case recordingSince = "recordingSince"
    case todayTotal     = "todayTotal"
    case avgInterval    = "avgInterval"
    case estimatedWPM   = "estimatedWPM"
    case backspaceRate  = "backspaceRate"
    case miniChart            = "miniChart"
    case streak               = "streak"
    case shortcutEfficiency   = "shortcutEfficiency"
    case mouseDistance        = "mouseDistance"

    var id: String { rawValue }

    /// Display name shown in the Customize Menu panel.
    /// カスタマイズパネルに表示する名前。
    var displayName: String {
        L10n.shared.widgetDisplayName(self)
    }
}

// MARK: - MenuWidgetStore

/// Persists the user's widget selection and ordering in UserDefaults.
/// ウィジェットの選択状態と順序を UserDefaults に永続化するシングルトン。
final class MenuWidgetStore: ObservableObject {
    static let shared = MenuWidgetStore()

    /// Incremented on every change to trigger SwiftUI re-renders.
    /// 変更のたびにインクリメントし SwiftUI の再描画を促す。
    @Published private(set) var revision: Int = 0

    private let orderKey   = "menuWidgetOrder"
    private let enabledKey = "menuWidgetEnabled"

    /// Default order matching current hardcoded behaviour.
    /// 既存の表示順と一致するデフォルト順序。
    static let defaultOrder: [MenuWidget] = [
        .recordingSince, .todayTotal, .avgInterval, .estimatedWPM, .backspaceRate, .miniChart
    ]

    private init() {}

    // MARK: - Ordering

    /// Ordered list of all widgets (enabled and disabled).
    /// 全ウィジェットを順序通りに返す（ON/OFF 問わず）。
    var allOrdered: [MenuWidget] {
        get {
            guard let raw = UserDefaults.standard.array(forKey: orderKey) as? [String] else {
                return Self.defaultOrder
            }
            // reconstruct from stored order, appending any new widgets not yet stored
            let stored = raw.compactMap { MenuWidget(rawValue: $0) }
            let missing = MenuWidget.allCases.filter { !stored.contains($0) }
            return stored + missing
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue), forKey: orderKey)
            revision += 1
        }
    }

    // MARK: - Enabled state

    func isEnabled(_ widget: MenuWidget) -> Bool {
        let key = enabledKey + "." + widget.rawValue
        // Default: all widgets enabled
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    func setEnabled(_ widget: MenuWidget, _ value: Bool) {
        let key = enabledKey + "." + widget.rawValue
        UserDefaults.standard.set(value, forKey: key)
        revision += 1
    }

    // MARK: - Convenience

    /// Ordered list of only the enabled widgets.
    /// 有効なウィジェットのみを順序通りに返す。
    var orderedEnabled: [MenuWidget] {
        allOrdered.filter { isEnabled($0) }
    }
}
