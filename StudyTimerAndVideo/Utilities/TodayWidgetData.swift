import Foundation
import WidgetKit

// ホーム画面・ロック画面のウィジェット「今日の目標まであと◯分」に渡す数字。App Group の UserDefaults に書く
enum TodayWidgetData {
    static let suiteName = "group.com.ni.StudyTimerAndVideo"
    static let kind = "StudyReelToday"
    static let dayKey = "today_widget_day"
    static let secondsKey = "today_widget_seconds"
    static let goalKey = "today_widget_goal"
    static let proKey = "today_widget_pro"

    static func update(todaySeconds: Int, goalSeconds: Int?, isPro: Bool, now: Date = Date()) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        let goal = goalSeconds ?? 0
        // 変わっていなければウィジェットを描き直さない
        if defaults.double(forKey: dayKey) == day, defaults.integer(forKey: secondsKey) == todaySeconds,
           defaults.integer(forKey: goalKey) == goal, defaults.bool(forKey: proKey) == isPro {
            return
        }
        defaults.set(day, forKey: dayKey)
        defaults.set(todaySeconds, forKey: secondsKey)
        defaults.set(goal, forKey: goalKey)
        defaults.set(isPro, forKey: proKey)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
