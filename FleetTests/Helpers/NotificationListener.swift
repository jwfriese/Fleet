import Foundation

class NotificationListener: NSObject {
    private(set) var notificationsReceived: [Notification.Name] = []

    @objc func listenTo(notification: Notification) {
        notificationsReceived.append(notification.name)
    }

    func callCount(for notificationType: Notification.Name) -> Int {
        return notificationsReceived
            .filter { $0 == notificationType }
            .count
    }
}
