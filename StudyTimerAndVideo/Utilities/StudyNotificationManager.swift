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
        content.title = L10n.string("そろそろ勉強の時間です")
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

    // MARK: - ポモドーロの区切り（アプリを離れていても知らせる）

    private let pomodoroIdentifier = "studyreel.pomodoro"

    func schedulePomodoro(title: String, body: String, after seconds: Int) async {
        guard seconds > 0, await requestAuthorizationIfNeeded() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [pomodoroIdentifier])
        try? await center.add(UNNotificationRequest(identifier: pomodoroIdentifier, content: content, trigger: trigger))
    }

    func clearPomodoro() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pomodoroIdentifier])
    }

    // MARK: - 毎週日曜の夜の「今週の勉強」と、年末の「今年の Vlog」

    static let weeklySummaryKey = "weekly_summary_enabled"
    private let weeklyIdentifier = "studyreel.weekly-summary"
    private let yearIdentifier = "studyreel.year-vlog"

    var isWeeklySummaryEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.weeklySummaryKey) as? Bool ?? true
    }

    // 通知の中身は予約したときの記録で決まるので、記録を保存するたびとホームを開いたときに予約し直す。
    // 通知の許可はここでは求めない（ほかの通知で許可されているときだけ届ける）
    func scheduleWeeklySummary(with sessions: [StudySession], isPro: Bool, now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier, yearIdentifier])
        guard isWeeklySummaryEnabled else { return }
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        var match = DateComponents()
        match.weekday = 1
        match.hour = 20
        guard let fire = calendar.nextDate(after: now, matching: match, matchingPolicy: .nextTime),
              let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: fire)),
              let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }

        let thisWeek = sessions.filter { $0.date >= weekStart && $0.date < fire }
        let lastWeek = sessions.filter { $0.date >= lastWeekStart && $0.date < weekStart }
        let content = UNMutableNotificationContent()
        content.title = L10n.string("今週の勉強")
        content.body = Self.weeklyBody(thisWeek: thisWeek, lastWeek: lastWeek, isPro: isPro, calendar: calendar)
        content.sound = .default
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        try? await center.add(UNNotificationRequest(identifier: weeklyIdentifier, content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))

        // 12月は、大みそかの夜に「今年の勉強を1本の Vlog に」と知らせる
        if calendar.component(.month, from: now) == 12 {
            var year = calendar.dateComponents([.year], from: now)
            year.month = 12
            year.day = 31
            year.hour = 20
            if let date = calendar.date(from: year), date > now {
                let yearContent = UNMutableNotificationContent()
                yearContent.title = L10n.string("今年の勉強を1分の Vlog に")
                yearContent.body = L10n.string("1年分のタイムラプスから、週ごとに1本ずつ選んでまとめます。")
                yearContent.sound = .default
                try? await center.add(UNNotificationRequest(identifier: yearIdentifier, content: yearContent,
                                                            trigger: UNCalendarNotificationTrigger(dateMatching: year, repeats: false)))
            }
        }
    }

    static func weeklyBody(thisWeek: [StudySession], lastWeek: [StudySession], isPro: Bool, calendar: Calendar = .current) -> String {
        let total = thisWeek.reduce(0) { $0 + $1.duration }
        guard total > 0 else {
            return L10n.string("今週は記録がありませんでした。来週は5分だけでも始めてみませんか。")
        }
        let days = Set(thisWeek.map { calendar.startOfDay(for: $0.date) }).count
        var parts = [L10n.format("合計 %@・%d日勉強しました", durationText(total), days)]
        if isPro {
            let last = lastWeek.reduce(0) { $0 + $1.duration }
            if last > 0 {
                let diff = total - last
                parts.append(diff >= 0
                    ? L10n.format("先週より %@ 多い", durationText(diff))
                    : L10n.format("先週より %@ 少ない", durationText(-diff)))
            }
            var byHour: [Int: Int] = [:]
            for session in thisWeek {
                byHour[calendar.component(.hour, from: session.date), default: 0] += session.duration
            }
            if let best = byHour.max(by: { $0.value < $1.value })?.key {
                parts.append(L10n.format("よく勉強したのは%d時台", best))
            }
        }
        return parts.joined(separator: "。") + "。"
    }

    private static func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 60 { return L10n.format("%d分", minutes) }
        return minutes % 60 == 0 ? L10n.format("%d時間", minutes / 60) : L10n.format("%d時間%d分", minutes / 60, minutes % 60)
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
