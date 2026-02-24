import AppKit
import SwiftUI

// MARK: - OverlayEntry

struct OverlayEntry: Identifiable {
    let id = UUID()
    let symbol: String
}

// MARK: - OverlayViewModel

final class OverlayViewModel: ObservableObject {
    @Published var keys: [OverlayEntry] = []
    @Published var opacity: Double = 0.0

    private var fadeTimer: DispatchWorkItem?
    private let maxVisible = 10
    private let fadeDelay = 3.0

    func append(keyName: String) {
        let entry = OverlayEntry(symbol: Self.symbol(for: keyName))
        keys.append(entry)
        if keys.count > maxVisible { keys.removeFirst() }

        withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }

        fadeTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.6)) { self?.opacity = 0.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                self?.keys = []
            }
        }
        fadeTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay, execute: work)
    }

    static func symbol(for key: String) -> String {
        let map: [String: String] = [
            "Return":     "↵",
            "Delete":     "⌫",
            "Space":      "⎵",
            "Tab":        "⇥",
            "Escape":     "⎋",
            "Enter(Num)": "↵",
            "⌦FwdDel":   "⌦",
            "⌘Cmd":      "⌘",
            "⇧Shift":    "⇧",
            "⌥Option":   "⌥",
            "⌃Ctrl":     "⌃",
            "CapsLock":   "⇪",
        ]
        return map[key] ?? key
    }
}

// MARK: - OverlayView

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.keys) { entry in
                Text(entry.symbol)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 28)
                    .fixedSize()  // 省略記号（...）を防ぐ
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.55))
        )
        .fixedSize()  // コンテンツの理想サイズで表示
        .opacity(viewModel.opacity)
    }
}

// MARK: - KeystrokeOverlayController

final class KeystrokeOverlayController {
    static let shared = KeystrokeOverlayController()
    static let enabledKey = "overlayEnabled"

    private let panel: NSPanel
    private let viewModel = OverlayViewModel()
    // NSHostingController をプロパティとして保持（解放を防ぐ）
    private let hostVC: NSHostingController<OverlayView>
    private var observer: NSObjectProtocol?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            newValue ? startListening() : stopListening()
            if !newValue { panel.orderOut(nil) }
        }
    }

    private init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // contentViewController 経由で設定することで、NSPanel が VC のライフタイムを管理する
        hostVC = NSHostingController(rootView: OverlayView(viewModel: viewModel))
        panel.contentViewController = hostVC

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if isEnabled { startListening() }
    }

    // MARK: - Positioning

    @objc private func repositionPanel() {
        guard panel.isVisible else { return }
        placePanel()
    }

    private func placePanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let f = screen.visibleFrame
        panel.contentView?.layoutSubtreeIfNeeded()
        let s = panel.contentView?.fittingSize ?? NSSize(width: 280, height: 50)
        let size = NSSize(width: max(s.width, 60), height: max(s.height, 44))
        panel.setFrame(
            NSRect(origin: NSPoint(x: f.minX + 20, y: f.minY + 20), size: size),
            display: true
        )
    }

    // MARK: - Listening

    private func startListening() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .keystrokeInput,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, let key = note.object as? String else { return }
            // append を先に呼ぶことで、placePanel() のサイズ計算が最新状態に基づく
            self.viewModel.append(keyName: key)
            if !self.panel.isVisible {
                self.panel.orderFront(nil)
            }
            // SwiftUI のレイアウトが確定してからサイズを更新する
            DispatchQueue.main.async { [weak self] in
                self?.placePanel()
            }
        }
    }

    private func stopListening() {
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            observer = nil
        }
        viewModel.keys = []
        viewModel.opacity = 0.0
    }
}
