import UserNotifications

/// macOS 通知を発行するシングルトン
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[KeyCounter] 通知権限エラー: \(error)")
            }
        }
    }

    /// 指定キーがマイルストーン（1000の倍数）に達した通知を送る
    func notify(key: String, count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⌨️ KeyCounter"
        content.body = "「\(key)」が \(count.formatted()) 回に達しました！"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // trigger=nil で即時配信
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[KeyCounter] 通知送信エラー: \(error)")
            }
        }
    }
}
