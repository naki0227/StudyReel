import Foundation

// 目標をつくる画面の候補。毎年の決まりで日付が決まる試験は、次の試験日を期日に入れる。
// 日付は年ごとに変わることがあるので、画面では「公式サイトで確かめてください」と添える
struct ExamPreset: Identifiable {
    enum DateRule {
        case none
        // 1月13日〜19日の土曜（大学入学共通テストの1日目）
        case kyotsuTest
        // 毎年同じ月日（国公立大学の前期日程は2月25日）
        case fixed(month: Int, day: Int)
        // その月の第n日曜（宅建は10月の第3日曜、行政書士は11月の第2日曜）
        case nthSunday(month: Int, nth: Int)
    }

    let title: String
    let targetScore: Int?
    let maxScore: Int?
    let rule: DateRule

    var id: String { title }

    static let all: [ExamPreset] = [
        ExamPreset(title: "TOEIC 800点", targetScore: 800, maxScore: 990, rule: .none),
        ExamPreset(title: "共通テスト 8割", targetScore: 720, maxScore: 900, rule: .kyotsuTest),
        ExamPreset(title: "国公立 前期 合格", targetScore: nil, maxScore: nil, rule: .fixed(month: 2, day: 25)),
        ExamPreset(title: "英検2級 合格", targetScore: nil, maxScore: nil, rule: .none),
        ExamPreset(title: "宅建 合格", targetScore: nil, maxScore: nil, rule: .nthSunday(month: 10, nth: 3)),
        ExamPreset(title: "行政書士 合格", targetScore: nil, maxScore: nil, rule: .nthSunday(month: 11, nth: 2)),
        ExamPreset(title: "基本情報 合格", targetScore: nil, maxScore: nil, rule: .none),
    ]

    // 今日より後で、いちばん近い試験日（決まりがなければ nil）
    func nextDate(after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let year = calendar.component(.year, from: today)
        for candidateYear in year...(year + 1) {
            if let date = date(in: candidateYear, calendar: calendar), date >= today {
                return date
            }
        }
        return nil
    }

    func date(in year: Int, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .none:
            return nil
        case .kyotsuTest:
            for day in 13...19 {
                if let date = calendar.date(from: DateComponents(year: year, month: 1, day: day)),
                   calendar.component(.weekday, from: date) == 7 {
                    return date
                }
            }
            return nil
        case let .fixed(month, day):
            return calendar.date(from: DateComponents(year: year, month: month, day: day))
        case let .nthSunday(month, nth):
            // weekday 1 は日曜
            return calendar.date(from: DateComponents(year: year, month: month, weekday: 1, weekdayOrdinal: nth))
        }
    }
}
