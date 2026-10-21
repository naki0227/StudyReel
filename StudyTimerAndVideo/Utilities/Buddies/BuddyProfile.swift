import Foundation
import SwiftUI

// 勉強仲間で見せる自分の名前とアイコン。iCloud の名前や本名は使わない
// 4桁の番号は最初に一度だけ決めて変えない。参加申請のときに「この番号で申請したよ」と伝えるのに使う
enum BuddyProfile {
    private static let nicknameKey = "buddy_nickname"
    private static let iconKey = "buddy_icon"
    private static let codeKey = "buddy_code"
    private static let hidesRankingKey = "buddy_hides_ranking"

    static let maxNicknameLength = 20

    static var nickname: String {
        get { UserDefaults.standard.string(forKey: nicknameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nicknameKey) }
    }

    static var icon: BuddyIcon {
        get { BuddyIcon(rawValue: UserDefaults.standard.string(forKey: iconKey) ?? "") ?? .pencil }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: iconKey) }
    }

    static var code: Int {
        let saved = UserDefaults.standard.integer(forKey: codeKey)
        if saved >= 1000 { return saved }
        let made = Int.random(in: 1000...9999)
        UserDefaults.standard.set(made, forKey: codeKey)
        return made
    }

    static var hidesRanking: Bool {
        get { UserDefaults.standard.bool(forKey: hidesRankingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hidesRankingKey) }
    }

    static var isReady: Bool { !nickname.trimmingCharacters(in: .whitespaces).isEmpty }

    // 資格ごとの人数で、自分を数えてもらう資格。選ばなければ数えられない
    static var exam: BuddyExam? {
        get { BuddyExam(rawValue: UserDefaults.standard.string(forKey: examKey) ?? "") }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: examKey) }
    }

    // 写真を見せ合うか。18歳未満と分かった人は、自分でオンにするまでオフ
    static var photosOn: Bool {
        get { UserDefaults.standard.object(forKey: photosKey) as? Bool ?? !isUnder18 }
        set { UserDefaults.standard.set(newValue, forKey: photosKey) }
    }

    // 「年齢の範囲」（iOS 26）で18歳未満と分かったとき
    static var isUnder18: Bool {
        get { UserDefaults.standard.bool(forKey: under18Key) }
        set { UserDefaults.standard.set(newValue, forKey: under18Key) }
    }

    static var notifiesStamps: Bool {
        get { UserDefaults.standard.object(forKey: stampNoticeKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: stampNoticeKey) }
    }

    static var notifiesStudying: Bool {
        get { UserDefaults.standard.bool(forKey: studyingNoticeKey) }
        set { UserDefaults.standard.set(newValue, forKey: studyingNoticeKey) }
    }

    private static let examKey = "buddy_exam"
    private static let photosKey = "buddy_photos_on"
    private static let under18Key = "buddy_under18"
    private static let stampNoticeKey = "buddy_notice_stamps"
    private static let studyingNoticeKey = "buddy_notice_studying"

    static func displayCode(_ code: Int) -> String { "#\(code)" }
}

// 用意した絵柄から選ぶアイコン。写真は使えない
enum BuddyIcon: String, CaseIterable, Identifiable {
    case pencil, book, star, leaf, moon, sun, cloud, flame, heart, cap, bulb, note, paw, cup, plane, bolt

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pencil: return "pencil"
        case .book: return "book.closed"
        case .star: return "star"
        case .leaf: return "leaf"
        case .moon: return "moon"
        case .sun: return "sun.max"
        case .cloud: return "cloud"
        case .flame: return "flame"
        case .heart: return "heart"
        case .cap: return "graduationcap"
        case .bulb: return "lightbulb"
        case .note: return "music.note"
        case .paw: return "pawprint"
        case .cup: return "cup.and.saucer"
        case .plane: return "paperplane"
        case .bolt: return "bolt"
        }
    }
}

// 資格ごとの人数を数える資格・試験。一覧はこちらで用意し、利用者は作れない
enum BuddyExam: String, CaseIterable, Identifiable {
    case toeic, eiken, toefl, ielts, kyotsu, juken, koukou, takken, boki, fp, fe, ap, itpass, kanken, koumuin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toeic: return "TOEIC"
        case .eiken: return L10n.string("英検")
        case .toefl: return "TOEFL"
        case .ielts: return "IELTS"
        case .kyotsu: return L10n.string("共通テスト")
        case .juken: return L10n.string("大学受験")
        case .koukou: return L10n.string("高校受験")
        case .takken: return L10n.string("宅建")
        case .boki: return L10n.string("簿記")
        case .fp: return "FP"
        case .fe: return L10n.string("基本情報技術者")
        case .ap: return L10n.string("応用情報技術者")
        case .itpass: return L10n.string("ITパスポート")
        case .kanken: return L10n.string("漢検")
        case .koumuin: return L10n.string("公務員試験")
        }
    }
}

// 仲間に送れるスタンプ。用意したものだけで、文字は送れない
enum BuddyStampKind: String, CaseIterable, Identifiable {
    case otsukare, ganbare, sugoi, issho, kyukei, omedeto, miteru, oyasumi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .otsukare: return L10n.string("おつかれ")
        case .ganbare: return L10n.string("がんばれ")
        case .sugoi: return L10n.string("すごい")
        case .issho: return L10n.string("一緒にやろ")
        case .kyukei: return L10n.string("休憩しよ")
        case .omedeto: return L10n.string("おめでとう")
        case .miteru: return L10n.string("見てるよ")
        case .oyasumi: return L10n.string("おやすみ")
        }
    }

    var systemImage: String {
        switch self {
        case .otsukare: return "hands.clap"
        case .ganbare: return "flame"
        case .sugoi: return "sparkles"
        case .issho: return "person.2"
        case .kyukei: return "cup.and.saucer"
        case .omedeto: return "party.popper"
        case .miteru: return "eyes"
        case .oyasumi: return "moon.zzz"
        }
    }
}

// ニックネームとグループ名に入れられない言葉。簡単な一覧で弾く
enum BuddyWordFilter {
    private static let blocked = [
        "死ね", "しね", "殺す", "ころす", "きもい", "キモい", "ちんこ", "ちんぽ", "まんこ", "セックス", "エロ", "レイプ", "おっぱい",
        "sex", "fuck", "shit", "porn", "nude", "rape", "kill", "dick", "pussy", "bitch",
    ]

    static func isAllowed(_ text: String) -> Bool {
        let folded = text.lowercased().replacingOccurrences(of: " ", with: "")
        return !blocked.contains { folded.contains($0.lowercased()) }
    }
}

// 自分の勉強時間の合計。保存した記録から数える
struct BuddyTotals: Equatable {
    var todaySeconds = 0
    var weekSeconds = 0
    var streakDays = 0

    static func make(from sessions: [StudySession], now: Date = Date(), calendar: Calendar = .current) -> BuddyTotals {
        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        var totals = BuddyTotals()
        var days = Set<Date>()
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            days.insert(day)
            if day == today { totals.todaySeconds += session.duration }
            if let week, week.contains(session.date) { totals.weekSeconds += session.duration }
        }
        // 今日まだ勉強していなくても、昨日まで続いていれば連続とみなす
        var day = days.contains(today) ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        while days.contains(day) {
            totals.streakDays += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return totals
    }

    // 日付と週を、見る人の端末でも比べられる形にする
    static func dayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func weekKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return dayKey(start, calendar: calendar)
    }
}

// 時間の見せ方（「1時間25分」「45分」）
func buddyDuration(_ seconds: Int) -> String {
    let minutes = max(seconds, 0) / 60
    if minutes >= 60 { return L10n.format("%d時間%d分", minutes / 60, minutes % 60) }
    return L10n.format("%d分", minutes)
}
