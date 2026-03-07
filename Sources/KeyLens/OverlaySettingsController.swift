import AppKit
import SwiftUI
import KeyLensCore

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
    case extraLarge = "extraLarge"

    var pointSize: CGFloat {
        switch self {
        case .small:  return 24
        case .medium: return 36
        case .large:  return 52
        case .extraLarge: return 72
        }
    }

    var displayName: String {
        let l = L10n.shared
        switch self {
        case .small:  return l.overlaySizeSmall
        case .medium: return l.overlaySizeMedium
        case .large:  return l.overlaySizeLarge
        case .extraLarge: return l.overlaySizeExtraLarge
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
    var fontColor:         String          = "#FFFFFF"
    var backgroundColor:   String          = "#000000"
    var cornerRadius:      Double          = 10.0
    // Custom position set by dragging (nil = use preset position)
    // ドラッグで設定したカスタム位置（nil = プリセット位置を使用）
    var customX:           Double?         = nil
    var customY:           Double?         = nil

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                positionSection
                fadeDelaySection
                sizeAndCodeSection
                appearanceSection
                previewSection
            }
            .padding(20)
        }
        .frame(width: 380, height: 500)
        .onChange(of: config) { newConfig in
            newConfig.save()
            previewVM.config = newConfig
        }
    }

    // MARK: - Sections

    private var sizeAndCodeSection: some View {
        HStack(spacing: 12) {
            fontSizeSection
            showKeyCodeSection
        }
    }

    private var appearanceSection: some View {
        let l = L10n.shared
        return GroupBox(label: Text(ja("外観", en: "Appearance")).fontWeight(.medium)) {
            VStack(spacing: 12) {
                HStack {
                    Text(l.overlaySettingsFontColor).font(.subheadline)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: config.fontColor) ?? .white },
                        set: { config.fontColor = $0.toHex() ?? "#FFFFFF" }
                    ))
                    .labelsHidden()
                }

                HStack {
                    Text(l.overlaySettingsBackgroundColor).font(.subheadline)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: config.backgroundColor) ?? .black },
                        set: { config.backgroundColor = $0.toHex() ?? "#000000" }
                    ))
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(l.overlaySettingsOpacity).font(.subheadline)
                        Spacer()
                        Text("\(Int(config.backgroundOpacity * 100))%").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $config.backgroundOpacity, in: 0.1...1.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(l.overlaySettingsCornerRadius).font(.subheadline)
                        Spacer()
                        Text("\(Int(config.cornerRadius))px").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $config.cornerRadius, in: 0...30)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func ja(_ japanese: String, en english: String) -> String {
        L10n.shared.resolved == .japanese ? japanese : english
    }

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
        Button(action: {
            config.position = pos
            // Clear custom drag position so the preset takes effect
            // プリセット選択時はドラッグ位置をリセットする
            config.customX = nil
            config.customY = nil
        }) {
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

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: Double
        if hexSanitized.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0

        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX",
                          lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX",
                          lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
