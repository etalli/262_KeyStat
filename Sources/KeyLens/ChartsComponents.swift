import SwiftUI

// MARK: - SectionHeader

/// Section title with an optional hover-triggered help popover.
/// セクションタイトル + ホバーで表示されるヘルプポップオーバー（任意）。
struct SectionHeader: View {
    let title: String
    let helpText: String
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(showHelp ? .primary : .secondary)
                .onHover { showHelp = $0 }
                .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                    Text(helpText)
                        .font(.callout)
                        .padding(10)
                        .frame(width: 280)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
    }
}

// MARK: - ChartTab

enum ChartTab: String, CaseIterable, Identifiable {
    case summary     = "Summary"
    case live        = "Live"
    case activity    = "Activity"
    case keyboard    = "Keyboard"
    case ergonomics  = "Ergonomics"
    case shortcuts   = "Shortcuts"
    case apps        = "Apps"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .summary:    return "info.circle"
        case .live:       return "waveform"
        case .activity:   return "chart.line.uptrend.xyaxis"
        case .keyboard:   return "square.grid.3x3"
        case .ergonomics: return "figure.walk"
        case .shortcuts:  return "command"
        case .apps:       return "app.badge"
        }
    }
}
