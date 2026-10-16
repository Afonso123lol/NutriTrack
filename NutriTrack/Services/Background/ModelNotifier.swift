import UIKit
import UserNotifications

enum ModelNotifier {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(kind: ModelJobKind, succeeded: Bool) {
        guard ModelNotification.shouldNotify(applicationState: UIApplication.shared.applicationState) else { return }
        let text = ModelNotification.content(for: kind, succeeded: succeeded)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString,
                                                                     content: content, trigger: nil))
    }
}
