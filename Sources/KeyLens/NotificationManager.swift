import UserNotifications

/// macOS 通知を発行するシングルトン
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            KeyLens.log("notification auth — granted: \(granted), error: \(error?.localizedDescription ?? "none")")
        }
    }

    /// 指定キーがマイルストーン（1000の倍数）に達した通知を送る
    func notify(key: String, count: Int) {
        KeyLens.log("notify() called — key: \(key), count: \(count)")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            KeyLens.log("notification authorizationStatus: \(settings.authorizationStatus.rawValue)")
        }

        let content = UNMutableNotificationContent()
        content.title = "⌨️ KeyLens"
        content.body = L10n.shared.notificationBody(key: key, count: count)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // trigger=nil で即時配信
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                KeyLens.log("notification send error: \(error.localizedDescription)")
            } else {
                KeyLens.log("notification queued successfully")
            }
        }
    }
}
