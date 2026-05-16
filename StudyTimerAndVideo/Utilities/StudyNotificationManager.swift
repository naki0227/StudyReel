import Foundation
import UserNotifications

@MainActor
final class StudyNotificationManager {
    static let shared = StudyNotificationManager()

    private let quietReminderKey = "quiet_focus_reminder_enabled"
    private let reminderIdentifier = "studyreel.quiet-focus-reminder"

    private init() {}

    var isQuietReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: quietReminderKey)
    }

    func setQuietReminderEnabled(_ enabled: Bool, sessions: [StudySession]) async -> Bool {
        if enabled {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else {
                UserDefaults.standard.set(false, forKey: quietReminderKey)
                await clearPendingQuietReminder()
                return false
            }

            UserDefaults.standard.set(true, forKey: quietReminderKey)
            await scheduleQuietReminderIfNeeded(with: sessions)
            return true
        }

        UserDefaults.standard.set(false, forKey: quietReminderKey)
        await clearPendingQuietReminder()
        return false
    }

    func scheduleQuietReminderIfNeeded(with sessions: [StudySession]) async {
        guard isQuietReminderEnabled else { return }
        guard let nextDate = StudyInsights.preferredReminderDate(for: sessions) else {
            await clearPendingQuietReminder()
            return
        }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = L10n.string("そろそろ StudyReel に入る時間です")
        content.body = StudyInsights.quietReminderBody(for: sessions)
        content.sound = .default

        let interval = max(60, nextDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        try? await center.add(request)
    }

    func clearPendingQuietReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
