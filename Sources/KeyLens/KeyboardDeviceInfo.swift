import Foundation
import IOKit.hid

// MARK: - KeyboardDeviceInfo

/// IOHIDManager を使って現在接続中のキーボードデバイス名を取得するユーティリティ
enum KeyboardDeviceInfo {

    /// 接続中のキーボード製品名を昇順で返す（重複除去済み）
    static func connectedNames() -> [String] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey:     kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        let names = devices
            .compactMap { IOHIDDeviceGetProperty($0, kIOHIDProductKey as CFString) as? String }
            .filter { !$0.isEmpty }

        // 重複除去して昇順に返す
        return Array(Set(names)).sorted()
    }
}
