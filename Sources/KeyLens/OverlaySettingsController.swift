import AppKit
import SwiftUI

// MARK: - OverlayPosition

enum OverlayPosition: String, CaseIterable, Codable {
    case topLeft     = "topLeft"
    case topRight    = "topRight"
    case bottomLeft  = "bottomLeft"
    case bottomRight = "bottomRight"

    var displayName: String {
        let l = L10n.shared
        switch self {
        case .topLeft:     return l.overlayPositionTopLeft
        case .topRight:    return l.overlayPositionTopRight
        case .bottomLeft:  return l.overlayPositionBottomLeft
        case .bottomRight: return l.overlayPositionBottomRight
        }
    }
}

// MARK: - OverlayFontSize

enum OverlayFontSize: String, CaseIterable, Codable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    var pointSize: CGFloat {
        switch self {
        case .small:  return 16
        case .medium: return 22
        case .large:  return 30
        }
    }

    var displayName: String {
        let l = L10n.shared
        switch self {
        case .small:  return l.overlaySizeSmall
        case .medium: return l.overlaySizeMedium
        case .large:  return l.overlaySizeLarge
        }
    }
}

// MARK: - OverlayConfig

struct OverlayConfig: Codable, Equatable {
    var position:          OverlayPosition = .topLeft
    var fadeDelay:         Double          = 3.0
    var backgroundOpacity: Double          = 0.55
    var fontSize:          OverlayFontSize = .medium
    var showKeyCode:       Bool            = false

    static let userDefaultsKey = "overlayConfig"

    static var current: OverlayConfig {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let config = try? JSONDecoder().decode(OverlayConfig.self, from: data)
        else { return OverlayConfig() }
        return config
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        NotificationCenter.default.post(name: .overlayConfigDidChange, object: nil)
    }
}

extension Notification.Name {
    static let overlayConfigDidChange = Notification.Name("overlayConfigDidChange")
}

// MARK: - OverlaySettingsView

struct OverlaySettingsView: View {
    @State private var config: OverlayConfig = .current
    @StateObject private var previewVM: OverlayViewModel = {
        let vm = OverlayViewModel()
        vm.keys = [
            OverlayEntry(symbol: "A", keyCode: 0),
            OverlayEntry(symbol: "⌘", keyCode: 55),
            OverlayEntry(symbol: "↵", keyCode: 36),
        ]
        vm.opacity = 1.0
        return vm
    }()

    private let fadeDelayOptions: [Double] = [1, 2, 3, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            positionSection
            fadeDelaySection
            opacitySection
            fontSizeSection
            showKeyCodeSection
            previewSection
        }
        .padding(20)
        .frame(width: 380)
        .onChange(of: config) { newConfig in
            newConfig.save()
            previewVM.config = newConfig
        }
    }

    // MARK: - Sections

    private var positionSection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(l.overlaySettingsPosition).fontWeight(.medium)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    positionButton(.topLeft)
                    positionButton(.topRight)
                }
                HStack(spacing: 0) {
                    positionButton(.bottomLeft)
                    positionButton(.bottomRight)
                }
            }
            .padding(.top, 4)
        }
    }

    private func positionButton(_ pos: OverlayPosition) -> some View {
        Button(action: { config.position = pos }) {
            HStack(spacing: 4) {
                Image(systemName: config.position == pos ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(config.position == pos ? Color.accentColor : Color.secondary)
                Text(pos.displayName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private var fadeDelaySection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(l.overlaySettingsFadeDelay).fontWeight(.medium)) {
            Picker("", selection: $config.fadeDelay) {
                ForEach(fadeDelayOptions, id: \.self) { sec in
                    Text(l.overlayFadeDelayLabel(sec)).tag(sec)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.top, 4)
        }
    }

    private var opacitySection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(l.overlaySettingsOpacity).fontWeight(.medium)) {
            HStack {
                Slider(value: $config.backgroundOpacity, in: 0.1...1.0)
                Text("\(Int(config.backgroundOpacity * 100))%")
                    .frame(width: 38, alignment: .trailing)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var fontSizeSection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(l.overlaySettingsFontSize).fontWeight(.medium)) {
            Picker("", selection: $config.fontSize) {
                ForEach(OverlayFontSize.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.top, 4)
        }
    }

    private var showKeyCodeSection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(l.overlaySettingsShowKeyCode).fontWeight(.medium)) {
            Toggle(l.overlaySettingsShowKeyCode, isOn: $config.showKeyCode)
                .toggleStyle(.switch)
                .labelsHidden()
                .padding(.top, 4)
        }
    }

    private var previewSection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(l.overlaySettingsPreview).fontWeight(.medium)) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                OverlayView(viewModel: previewVM)
            }
            .frame(height: 70)
            .padding(.top, 4)
        }
    }
}

// MARK: - OverlaySettingsController

final class OverlaySettingsController: NSWindowController {
    static let shared = OverlaySettingsController()

    private init() {
        let hostVC = NSHostingController(rootView: OverlaySettingsView())
        let window = NSWindow(contentViewController: hostVC)
        window.title = L10n.shared.overlaySettingsWindowTitle
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 380, height: 500))
        window.center()
        window.setFrameAutosaveName("OverlaySettingsWindow")
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        if !(window?.isVisible ?? false) { window?.center() }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
