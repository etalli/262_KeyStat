import AppKit
import SwiftUI

// MARK: - ログ出力（~/Library/Logs/KeyLens/app.log に書き出す）
// main.swift から移動

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

// MARK: - App Entry Point

@main
struct KeyLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(appDelegate)
        } label: {
            Label("KeyLens", systemImage: "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}
