import AppKit
import Foundation

// MARK: - ログ出力（~/Library/Logs/KeyLens/app.log に書き出す）

enum KeyLens {
    private static let logURL: URL = {
        let dir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/KeyLens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }()

    static func log(_ message: String) {
        let line = "[\(Date().formatted(.iso8601))] \(message)\n"
        print(line, terminator: "")
        if let data = line.data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? line.data(using: .utf8)?.write(to: logURL, options: .atomic)
        }
    }
}

// MARK: - App entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // Dockに表示しない
let delegate = AppDelegate()
app.delegate = delegate
KeyLens.log("KeyLens launched — bundle: \(Bundle.main.bundlePath)")
app.run()
