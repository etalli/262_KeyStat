import AppKit

// MARK: - StatsWindowController

/// 全キー・マウスボタンの入力統計を一覧表示するウィンドウ
final class StatsWindowController: NSWindowController {

    static let shared = StatsWindowController()

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let headerLabel = NSTextField()
    private var entries: [(key: String, total: Int, today: Int)] = []

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyLens — All Inputs"
        window.center()
        window.setFrameAutosaveName("StatsWindow")
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Show

    func showWindow() {
        reload()
        if !(window?.isVisible ?? false) {
            window?.center()
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        entries = KeyCountStore.shared.allEntries()
        let store = KeyCountStore.shared
        let l = L10n.shared
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        fmt.locale = Locale(identifier: l.resolved == .japanese ? "ja_JP" : "en_US")
        headerLabel.stringValue = l.statsWindowHeader(
            since: fmt.string(from: store.startedAt),
            today: store.todayCount.formatted(),
            total: store.totalCount.formatted()
        )
        tableView.reloadData()
    }

    // MARK: - UI Construction

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // ヘッダーラベル
        headerLabel.isEditable = false
        headerLabel.isBordered = false
        headerLabel.backgroundColor = .clear
        headerLabel.font = .systemFont(ofSize: 12)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        // テーブル列定義
        let columns: [(id: String, title: String, width: CGFloat)] = [
            ("rank",  "#",     36),
            ("key",   "Key",  200),
            ("total", "Total", 90),
            ("today", "Today", 90),
        ]
        for col in columns {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
            c.title = col.title
            c.width = col.width
            c.minWidth = 30
            tableView.addTableColumn(c)
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

// MARK: - NSTableViewDataSource

extension StatsWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }
}

// MARK: - NSTableViewDelegate

extension StatsWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let col = tableColumn else { return nil }
        let entry = entries[row]

        let id = col.identifier.rawValue
        let text: String
        switch id {
        case "rank":  text = "\(row + 1)"
        case "key":   text = entry.key
        case "total": text = entry.total.formatted()
        case "today": text = entry.today > 0 ? entry.today.formatted() : "—"
        default: return nil
        }

        let cellID = NSUserInterfaceItemIdentifier(id + "Cell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
            let tf = NSTextField()
            tf.isEditable = false
            tf.isBordered = false
            tf.backgroundColor = .clear
            tf.translatesAutoresizingMaskIntoConstraints = false
            // rank / total / today は右寄せ
            if id == "rank" || id == "total" || id == "today" {
                tf.alignment = .right
                tf.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            }
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = text
        return cell
    }
}
