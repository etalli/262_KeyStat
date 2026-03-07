import AppKit
import SwiftUI

// MARK: - OverlayEntry

struct OverlayEntry: Identifiable {
    let id = UUID()
    let symbol: String
    let keyCode: UInt16?
}

// MARK: - OverlayViewModel

final class OverlayViewModel: ObservableObject {
    @Published var keys: [OverlayEntry] = []
    @Published var opacity: Double = 0.0
    @Published var config: OverlayConfig = .current

    private var fadeTimer: DispatchWorkItem?
    private let maxVisible = 10
    private var fadeDelay: Double { config.fadeDelay }

    init() {
        NotificationCenter.default.addObserver(
            forName: .overlayConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.config = .current
        }
    }

    func append(keyName: String, keyCode: UInt16) {
        let entry = OverlayEntry(symbol: Self.symbol(for: keyName), keyCode: keyCode)
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
        KeyboardMonitor.symbolMap[key] ?? key
    }
}

// MARK: - OverlayView

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.keys) { entry in
                VStack(spacing: 1) {
                    Text(entry.symbol)
                        .font(.system(size: viewModel.config.fontSize.pointSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: viewModel.config.fontColor) ?? .white)
                        .frame(minWidth: 28)
                        .fixedSize()  // 省略記号（...）を防ぐ
                    if viewModel.config.showKeyCode, let code = entry.keyCode {
                        Text("\(code)")
                            .font(.system(size: viewModel.config.fontSize.pointSize * 0.45, weight: .regular, design: .monospaced))
                            .foregroundStyle((Color(hex: viewModel.config.fontColor) ?? .white).opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: viewModel.config.cornerRadius, style: .continuous)
                .fill((Color(hex: viewModel.config.backgroundColor) ?? .black).opacity(viewModel.config.backgroundOpacity))
        )
        .fixedSize()  // コンテンツの理想サイズで表示
        .opacity(viewModel.opacity)
    }
}

// MARK: - KeystrokeOverlayController

final class KeystrokeOverlayController: NSObject, NSWindowDelegate {
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

    private override init() {
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
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // contentViewController 経由で設定することで、NSPanel が VC のライフタイムを管理する
        hostVC = NSHostingController(rootView: OverlayView(viewModel: viewModel))

        super.init()

        panel.contentViewController = hostVC
        panel.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: .overlayConfigDidChange,
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
        let config = OverlayConfig.current
        let origin: NSPoint
        // Use custom dragged position if set; otherwise fall back to preset corner
        // ドラッグ後のカスタム位置があればそれを使い、なければプリセットコーナーを使う
        if let cx = config.customX, let cy = config.customY {
            origin = NSPoint(x: cx, y: cy)
        } else {
            let margin: CGFloat = 20
            switch config.position {
            case .topLeft:
                origin = NSPoint(x: f.minX + margin, y: f.maxY - size.height - margin)
            case .topRight:
                origin = NSPoint(x: f.maxX - size.width - margin, y: f.maxY - size.height - margin)
            case .bottomLeft:
                origin = NSPoint(x: f.minX + margin, y: f.minY + margin)
            case .bottomRight:
                origin = NSPoint(x: f.maxX - size.width - margin, y: f.minY + margin)
            }
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    // NSWindowDelegate: save position when user drags the panel
    // ドラッグ終了後に位置を保存する
    func windowDidMove(_ notification: Notification) {
        var config = OverlayConfig.current
        config.customX = Double(panel.frame.origin.x)
        config.customY = Double(panel.frame.origin.y)
        config.save()
    }

    // MARK: - Listening

    private func startListening() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .keystrokeInput,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, let evt = note.object as? KeystrokeEvent else { return }
            // append を先に呼ぶことで、placePanel() のサイズ計算が最新状態に基づく
            self.viewModel.append(keyName: evt.displayName, keyCode: evt.keyCode)
            if !self.panel.isVisible {
                self.panel.orderFront(nil)
            }
            // Enable mouse events while visible so the user can drag the overlay
            // 表示中はマウスイベントを有効にしてドラッグ可能にする
            self.panel.ignoresMouseEvents = false
            // SwiftUI のレイアウトが確定してからサイズを更新する
            DispatchQueue.main.async { [weak self] in
                self?.placePanel()
            }
            // Restore mouse passthrough after fade delay + animation
            // フェードアウト後にマウスパススルーを復元する
            let delay = self.viewModel.config.fadeDelay + 0.7
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.panel.ignoresMouseEvents = true
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
