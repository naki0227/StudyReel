import Foundation

// 集中と休憩のくり返し。休憩の間はタイマーと撮影を止めるので、保存する勉強時間とタイムラプスには集中した時間だけが入る
// 既定は 25/5。どれが一番よいかは研究でも決まっていないので、長めの型も選べるようにする（docs/research/science.md）
enum PomodoroPlan: String, CaseIterable, Identifiable {
    case off
    case classic   // 25分・5分、4回ごとに15分
    case long      // 50分・10分
    case deep      // 90分・15分

    static let storageKey = "pomodoro_plan"

    var id: String { rawValue }

    var focusSeconds: Int {
        switch self {
        case .off: return 0
        case .classic: return 25 * 60
        case .long: return 50 * 60
        case .deep: return 90 * 60
        }
    }

    // round は終わった集中の回数（1から）
    func breakSeconds(after round: Int) -> Int {
        switch self {
        case .off: return 0
        case .classic: return round % 4 == 0 ? 15 * 60 : 5 * 60
        case .long: return 10 * 60
        case .deep: return 15 * 60
        }
    }

    var title: String {
        switch self {
        case .off: return L10n.string("休憩なし")
        case .classic: return L10n.string("25分＋5分休憩")
        case .long: return L10n.string("50分＋10分休憩")
        case .deep: return L10n.string("90分＋15分休憩")
        }
    }

    var shortTitle: String {
        switch self {
        case .off: return ""
        case .classic: return "25/5"
        case .long: return "50/10"
        case .deep: return "90/15"
        }
    }

    static var saved: PomodoroPlan {
        PomodoroPlan(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .off
    }
}
