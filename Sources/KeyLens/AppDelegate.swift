import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isMonitoring = false
    let monitor = KeyboardMonitor()
    private var permissionTimer: Timer?
    private var healthTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NotificationManager.shared
        _ = KeystrokeOverlayController.shared

        startMonitor()
        setupHealthCheck()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Monitor

    @objc private func appDidBecomeActive() {
        guard !monitor.isRunning else { return }
        KeyLens.log("appDidBecomeActive — attempting monitor start")
        if monitor.start() {
            isMonitoring = true
            KeyLens.log("appDidBecomeActive — monitoring started")
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func startMonitor() {
        if monitor.start() {
            isMonitoring = true
            KeyLens.log("monitoring started")
        } else {
            // 現在のバイナリをアクセシビリティリストに登録し、設定画面を開く
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            schedulePermissionRetry()
        }
    }

    /// アクセシビリティ権限が付与されるまで 3 秒ごとにリトライする
    private func schedulePermissionRetry() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            KeyLens.log("permission retry tick — AXIsProcessTrusted: \(trusted)")
            guard trusted else { return }

            timer.invalidate()
            self.permissionTimer = nil

            if self.monitor.start() {
                self.isMonitoring = true
                KeyLens.log("permission granted -> monitoring started")
            } else {
                // 権限は付与されたが tap 作成失敗 → 自動再起動
                KeyLens.log("tap creation failed despite permission — auto-restarting")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.restartApp()
                }
            }
        }
    }

    /// 5 秒ごとに監視状態を確認し、停止していれば自動でリトライを開始する
    private func setupHealthCheck() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let running = self.monitor.isRunning
            if self.isMonitoring != running { self.isMonitoring = running }
            guard !running, self.permissionTimer == nil else { return }
            KeyLens.log("health check: monitor stopped — scheduling retry")
            self.schedulePermissionRetry()
        }
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
