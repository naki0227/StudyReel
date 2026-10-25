import Foundation

// 勉強した日の数え方。連続日数は、7日に1日までの休みなら途切れないことにする
// （途切れたことを強く見せると続かなくなるため。docs/research/science.md）
enum StudyStreak {
    // 今日まだ勉強していなくても、昨日まで続いていれば連続とみなす。数えるのは勉強した日だけ
    static func count(days: Set<Date>, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        var day = days.contains(today) ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        var streak = 0
        var lastRest: Date?
        while true {
            if days.contains(day) {
                streak += 1
            } else {
                // 休みは1日だけ。前の日に勉強していて、直近7日に休みを使っていないとき
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day), days.contains(previous) else { break }
                if let lastRest, let gap = calendar.dateComponents([.day], from: day, to: lastRest).day, gap < 7 { break }
                lastRest = day
            }
            guard let next = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = next
        }
        return streak
    }

    // しばらく休んでいたあと、まだ今日を始めていなければ、休んでいた日数を返す（3日以上）
    static func daysAway(days: Set<Date>, now: Date = Date(), calendar: Calendar = .current) -> Int? {
        let today = calendar.startOfDay(for: now)
        guard !days.contains(today), let last = days.filter({ $0 < today }).max(),
              let gap = calendar.dateComponents([.day], from: last, to: today).day, gap >= 3 else { return nil }
        return gap
    }
}

// 1年の草。日ごとの合計と、年の数字
struct StudyYear {
    let year: Int
    let start: Date
    let end: Date
    let seconds: [Date: Int]
    let totalSeconds: Int
    let studyDays: Int
    let longestStreak: Int

    init(sessions: [StudySession], year: Int, calendar: Calendar = .current) {
        self.year = year
        start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        var seconds: [Date: Int] = [:]
        for session in sessions where session.date >= start && session.date < end {
            seconds[calendar.startOfDay(for: session.date), default: 0] += session.duration
        }
        self.seconds = seconds
        totalSeconds = seconds.values.reduce(0, +)
        studyDays = seconds.count

        var longest = 0
        var run = 0
        var day = start
        while day < end {
            run = seconds[day] != nil ? run + 1 : 0
            longest = max(longest, run)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? end
        }
        longestStreak = longest
    }

    // 濃さは時間で決める（いちばん長い日に合わせると、ほかが薄くなるので）
    static func level(_ seconds: Int) -> Int {
        switch seconds {
        case ..<60: return 0
        case ..<1800: return 1
        case ..<3600: return 2
        case ..<7200: return 3
        default: return 4
        }
    }
}
