import AppKit
import SwiftUI

// MARK: - ChartDataModel

/// チャート用データを保持・更新する ObservableObject
final class ChartDataModel: ObservableObject {
    @Published var topKeys:     [TopKeyEntry]     = []
    @Published var dailyTotals: [DailyTotalEntry] = []
    @Published var categories:  [CategoryEntry]   = []
    @Published var perDayKeys:  [DailyKeyEntry]   = []
    @Published var shortcuts:   [ShortcutEntry]   = []

    func reload() {
        let store   = KeyCountStore.shared
        topKeys     = store.topKeys(limit: 20).map(TopKeyEntry.init)
        dailyTotals = store.dailyTotals().map(DailyTotalEntry.init)
        categories  = store.countsByType().map(CategoryEntry.init)
        perDayKeys  = store.topKeysPerDay(limit: 10).map(DailyKeyEntry.init)
        shortcuts   = store.topModifiedKeys(prefix: "⌘", limit: 20).map(ShortcutEntry.init)
    }
}

// MARK: - ChartsWindowController

/// Swift Charts を NSHostingController で包んで表示するウィンドウ
final class ChartsWindowController: NSWindowController {
    static let shared = ChartsWindowController()
    private let model = ChartDataModel()

    private init() {
        let hostVC = NSHostingController(rootView: ChartsView(model: model))
        let window = NSWindow(contentViewController: hostVC)
        window.title = "KeyLens — Charts"
        window.setContentSize(NSSize(width: 700, height: 650))
        window.center()
        window.setFrameAutosaveName("ChartsWindow")
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        model.reload()
        if !(window?.isVisible ?? false) { window?.center() }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
