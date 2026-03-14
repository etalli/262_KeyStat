import SwiftUI
import Charts
import KeyLensCore

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel
    @ObservedObject var theme = ThemeStore.shared

    @AppStorage("selectedChartTab") var selectedTab: ChartTab = .summary
    @AppStorage("frequentChartsSortDescending") var sortDescending: Bool = true

    /// Title of the section whose clipboard copy just succeeded (cleared after 1.5 s).
    @State var copiedSection: String? = nil
    /// Stores each chart section's SwiftUI global frame and the Charts NSWindow reference.
    @State var snapperStore = SnapperStore()
    /// Timer that drives real-time refresh on the Live tab.
    @State var liveTimer: Timer? = nil

    /// Fixed width keeps the live IKI snapshot compact when copying to the clipboard.
    /// 最新20打鍵グラフのコピーサイズを安定させるための固定幅。
    let recentIKIChartWidth: CGFloat = 560
    /// Slightly taller plot area leaves room for top annotations without making the snapshot too tall.
    /// 上端注釈が切れないように、コピー全体を伸ばしすぎず最小限だけ高さを増やす。
    let recentIKIPlotHeight: CGFloat = 200
    /// Extra Y-axis headroom prevents top annotations from being clipped at the 300ms ceiling.
    /// 300ms天井で上端注釈が切れないように、表示用のヘッドルームを少し確保する。
    let recentIKIChartMaxDisplay: Double = 340

    /// Set to true to show the actual key label above each IKI bar.
    /// WARNING: enabling this exposes keystrokes (including passwords) visually.
    /// Set to false (default) to hide key names for privacy.
    let ikichartShowKeyLabels = false

    var body: some View {
        TabView(selection: $selectedTab) {
            summaryTab
                .tabItem { Label(ChartTab.summary.rawValue, systemImage: ChartTab.summary.icon) }
                .tag(ChartTab.summary)

            liveTab
                .tabItem { Label(ChartTab.live.rawValue, systemImage: ChartTab.live.icon) }
                .tag(ChartTab.live)

            activityTab
                .tabItem { Label(ChartTab.activity.rawValue, systemImage: ChartTab.activity.icon) }
                .tag(ChartTab.activity)

            keyboardTab
                .tabItem { Label(ChartTab.keyboard.rawValue, systemImage: ChartTab.keyboard.icon) }
                .tag(ChartTab.keyboard)

            ergonomicsTab
                .tabItem { Label(ChartTab.ergonomics.rawValue, systemImage: ChartTab.ergonomics.icon) }
                .tag(ChartTab.ergonomics)

            shortcutsTab
                .tabItem { Label(ChartTab.shortcuts.rawValue, systemImage: ChartTab.shortcuts.icon) }
                .tag(ChartTab.shortcuts)

            appsTab
                .tabItem { Label(ChartTab.apps.rawValue, systemImage: ChartTab.apps.icon) }
                .tag(ChartTab.apps)
        }
        .padding(.top, 8)
        .frame(minWidth: 680, minHeight: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .topLeading) {
            // Grabs the NSWindow reference and silences the beep on plain typing.
            WindowGrabber(store: snapperStore).frame(width: 1, height: 1).opacity(0)
            KeySilencer().frame(width: 1, height: 1).opacity(0)
        }
    }

    // MARK: - Section wrapper

    func chartSection<C: View>(_ title: String, helpText: String? = nil, showSort: Bool = false, @ViewBuilder content: () -> C) -> some View {
        let contentView = AnyView(content())
        let isCopied = copiedSection == title
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let helpText {
                    SectionHeader(title: title, helpText: helpText)
                } else {
                    Text(title).font(.headline)
                }

                Spacer()

                if showSort {
                    Picker("", selection: $sortDescending) {
                        Image(systemName: "arrow.down.square").tag(true)
                            .help("Descending (Most frequent first)")
                        Image(systemName: "arrow.up.square").tag(false)
                            .help("Ascending (Least frequent first)")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }

                // Copy to clipboard button
                Button {
                    snapshotToClipboard(title: title)
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "clipboard")
                        .font(.body)
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy chart as image")
                .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            ZStack(alignment: .topLeading) {
                // ChartSnapper sits behind contentView as a ZStack sibling so it has
                // a proper NSView superview and an always-current frame at click time.
                ChartSnapper(store: snapperStore, key: title).allowsHitTesting(false)
                contentView
            }
        }
    }

    /// Captures the composited on-screen pixels for `title`'s section and writes to NSPasteboard.
    /// Uses GeometryReader (SwiftUI global frame) + CGWindowListCreateImage (Metal-compatible).
    func snapshotToClipboard(title: String) {
        guard let snapper = snapperStore.views[title],
              let superview = snapper.superview,
              let window = superview.window else { return }

        let scale = window.backingScaleFactor

        // Convert snapper.frame (superview coords) → window coords → screen coords.
        // snapper is a ZStack sibling of contentView, so its frame matches contentView exactly.
        let inWindow   = superview.convert(snapper.frame, to: nil)
        let onScreen   = window.convertToScreen(inWindow)
        let winOnScreen = window.frame

        guard let windowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return }

        // Map screen rect → CGImage pixel rect (top-left origin).
        let cropRect = CGRect(
            x:      (onScreen.minX - winOnScreen.minX) * scale,
            y:      (winOnScreen.maxY - onScreen.maxY) * scale,
            width:  onScreen.width  * scale,
            height: onScreen.height * scale
        )
        guard let cropped = windowImage.cropping(to: cropRect) else { return }

        let img = NSImage(cgImage: cropped,
                          size: NSSize(width: onScreen.width, height: onScreen.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
        copiedSection = title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedSection == title { copiedSection = nil }
        }
    }

    // MARK: - Empty state

    var emptyState: some View {
        Text("(no data yet)")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

// MARK: - NSView snapshot helpers

/// Reference-type store for chart NSViews and the Charts NSWindow.
/// Being a class means mutations don't trigger SwiftUI re-renders.
final class SnapperStore {
    var views: [String: NSView] = [:]
    weak var window: NSWindow?
}

/// Tiny invisible NSViewRepresentable whose only job is to supply the NSWindow reference.
private struct WindowGrabber: NSViewRepresentable {
    let store: SnapperStore
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        if store.window == nil {
            DispatchQueue.main.async { store.window = nsView.window }
        }
    }
}

/// Accepts first responder so plain typing into the Charts window is silently swallowed
/// instead of triggering the system beep. Cmd/Ctrl shortcuts are passed through normally.
private final class KeySilencerView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        // Plain typing is captured by the CGEvent tap — just swallow it here.
    }
}

private struct KeySilencer: NSViewRepresentable {
    func makeNSView(context: Context) -> KeySilencerView { KeySilencerView() }
    func updateNSView(_ nsView: KeySilencerView, context: Context) {}
}

/// Transparent NSView subclass used as a position anchor inside each chart section.
private final class SnapperHost: NSView {}

/// Registers the chart section's NSView into SnapperStore for later screen capture.
private struct ChartSnapper: NSViewRepresentable {
    let store: SnapperStore
    let key: String
    func makeNSView(context: Context) -> SnapperHost { SnapperHost() }
    func updateNSView(_ nsView: SnapperHost, context: Context) {
        store.views[key] = nsView
    }
}
