import Foundation
import UserNotifications

/// 长时间计时提醒：start 时安排一条 4 小时后触发的本地通知，stop / cancel 时撤掉。
/// 默认 4 小时；用户忘了停时打个招呼，避免一觉醒来一条 12 小时的「测试一下」记录。
final class TimerNotifications: Sendable {
    private let reminderIdentifier = "notimer.longRunning"
    private let reminderDelay: TimeInterval = 4 * 60 * 60

    /// 启动时调一次，用户拒绝就静默失败。
    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func scheduleLongRunningReminder(title: String, startedAt: Date) {
        let fireAt = startedAt.addingTimeInterval(reminderDelay)
        let interval = fireAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "还在计时吗？"
        content.body = "「\(title.isEmpty ? "未命名任务" : title)」已经计时 4 小时了，确认一下要不要停。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        center.add(request) { _ in }
    }

    func cancelLongRunningReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }
}
