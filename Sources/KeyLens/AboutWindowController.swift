import AppKit
import SwiftUI

// MARK: - AboutWindowController

final class AboutWindowController: NSObject {
    static let shared = AboutWindowController()

    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.isReleasedWhenClosed = false
            p.contentView = NSHostingView(rootView: AboutView())
            p.center()
            panel = p
        }
        // Update title in case language was changed
        panel?.title = L10n.shared.aboutMenuItem
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - AboutView

private struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    private let repoURL = URL(string: "https://github.com/etalli/262_KeyLens")!

    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }

            Text("KeyLens \(version)")
                .font(.title2)
                .fontWeight(.semibold)

            Link("github.com/etalli/262_KeyLens", destination: repoURL)
                .font(.callout)

            Button(L10n.shared.close) {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.escape)
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(width: 300)
    }
}
