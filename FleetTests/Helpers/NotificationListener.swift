import Foundation

class NotificationListener: NSObject {
    private var notificationsReceived: [Notification.Name : Int] = [:]

    @objc func listenFor(notification: Notification) {
        incrementCallCount(for: notification.name)
    }

    func callCount(for notificationType: Notification.Name) -> Int {
        if let callCount = notificationsReceived[notificationType] {
            return callCount
        }

        return 0
    }

    private func incrementCallCount(for notificationType: Notification.Name) {
        notificationsReceived[notificationType] = (callCount(for: notificationType) + 1)
    }
}
