import Foundation

// クエストとジェム。サーバーは使わない。
// - できたかどうかは、記録・目標・教材などの今のデータから決める（記録は iCloud にバックアップされるので、入れ直しても戻る）
// - 一度できたクエストは、あとで条件を外れても「できた」のまま残す
// - ジェムの残りは「もらった数 − 交換に使った数」で毎回計算する。お金では買えない
enum QuestAction: Equatable {
    case settings      // iCloud のバックアップ
    case dailyGoal
    case materials
    case newSession
    case share
    case weeklyVlog
    case buddies
}

struct Quest: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let gems: Int
    let action: QuestAction?
    let isDone: Bool
}

// クエストの判定に使う今の状態
struct QuestState {
    var hasBackup: Bool
    var iCloudAvailable: Bool
    var hasDailyGoal: Bool
    var materialCount: Int
    var sessionCount: Int
    var hasVideo: Bool
    var streak: Int
    var studyDayCount: Int
    var hasBuddies: Bool
}

enum QuestBook {
    static let doneKey = "quests_done"
    static let eventsKey = "quest_events"

    // 一覧を開いたなど、データには残らないことを覚えておく
    enum Event: String {
        case share
        case weeklyVlog
    }

    // ホームのカードが @AppStorage で見て描き直せるよう、カンマ区切りの文字で持つ
    private static var events: Set<String> {
        Set((UserDefaults.standard.string(forKey: eventsKey) ?? "").split(separator: ",").map(String.init))
    }

    static func mark(_ event: Event) {
        var all = events
        guard all.insert(event.rawValue).inserted else { return }
        UserDefaults.standard.set(all.sorted().joined(separator: ","), forKey: eventsKey)
    }

    private static func happened(_ event: Event) -> Bool {
        events.contains(event.rawValue)
    }

    // 段ごとに出す。前の段が全部できたら次の段が出る
    static func tiers(_ state: QuestState) -> [[Quest]] {
        let done = Set(UserDefaults.standard.stringArray(forKey: doneKey) ?? [])
        func quest(_ id: String, _ title: String, _ detail: String, gems: Int, action: QuestAction?, met: Bool) -> Quest {
            Quest(id: id, title: title, detail: detail, gems: gems, action: action, isDone: met || done.contains(id))
        }
        return [
            [
                quest("backup", L10n.string("記録を iCloud に残す"),
                      state.iCloudAvailable ? L10n.string("機種変更しても、記録と動画が戻せます。") : L10n.string("iPhone の設定で iCloud にサインインすると残せます。"),
                      gems: 10, action: .settings, met: state.hasBackup),
                quest("goal", L10n.string("1日の目標を決める"), L10n.string("毎日の目標まで、あと何分かが分かります。"),
                      gems: 10, action: .dailyGoal, met: state.hasDailyGoal),
                quest("material", L10n.string("教材を1つ登録する"), L10n.string("参考書ごとに時間がたまります。"),
                      gems: 10, action: .materials, met: state.materialCount > 0),
                quest("firstVideo", L10n.string("タイムラプスを1本保存する"), L10n.string("顔はモザイクで隠せます。"),
                      gems: 10, action: .newSession, met: state.hasVideo),
                quest("streak3", L10n.string("3日続けて記録する"), L10n.string("週に1日休んでも、続いたことになります。"),
                      gems: 10, action: .newSession, met: state.streak >= 3),
            ],
            [
                quest("share", L10n.string("勉強の記録を共有する"), L10n.string("今日や今週を画像にできます。"),
                      gems: 20, action: .share, met: happened(.share)),
                quest("vlog", L10n.string("1週間の Vlog を作る"), L10n.string("1週間分のタイムラプスを1本にまとめます。"),
                      gems: 20, action: .weeklyVlog, met: happened(.weeklyVlog)),
                quest("buddies", L10n.string("勉強仲間のグループに入る"), L10n.string("仲間がいま勉強しているかが分かります。"),
                      gems: 20, action: .buddies, met: state.hasBuddies),
                quest("streak7", L10n.string("7日続けて記録する"), L10n.string("1週間続いたら、習慣になり始めています。"),
                      gems: 20, action: .newSession, met: state.streak >= 7),
                quest("sessions10", L10n.string("記録を10回つける"), L10n.string("10回分の勉強が、1年の草に残ります。"),
                      gems: 20, action: .newSession, met: state.sessionCount >= 10),
            ],
            [
                quest("streak30", L10n.string("30日続けて記録する"), L10n.string("ここまで来たら、もう止まりません。"),
                      gems: 50, action: .newSession, met: state.streak >= 30),
                quest("sessions50", L10n.string("記録を50回つける"), L10n.string("50回分の積み重ねです。"),
                      gems: 50, action: .newSession, met: state.sessionCount >= 50),
            ],
        ]
    }

    // できたクエストを覚える（あとで条件を外れても、もらったジェムは減らさない）
    static func remember(_ tiers: [[Quest]]) {
        let ids = tiers.flatMap { $0 }.filter(\.isDone).map(\.id)
        let current = Set(UserDefaults.standard.stringArray(forKey: doneKey) ?? [])
        let merged = current.union(ids)
        if merged != current {
            UserDefaults.standard.set(Array(merged), forKey: doneKey)
        }
    }

    // いま見せる段（全部できていたら nil）
    static func currentTier(_ tiers: [[Quest]]) -> (index: Int, quests: [Quest])? {
        for (index, tier) in tiers.enumerated() where tier.contains(where: { !$0.isDone }) {
            return (index, tier)
        }
        return nil
    }

    static let gemsPerStudyDay = 2

    // もらったジェム：できたクエスト ＋ 勉強した日1日ごとに2
    static func earnedGems(_ tiers: [[Quest]], studyDayCount: Int) -> Int {
        tiers.flatMap { $0 }.filter(\.isDone).map(\.gems).reduce(0, +) + studyDayCount * gemsPerStudyDay
    }
}

// 交換所。ジェムと交換したものは、Pro でなくても使える
struct Reward: Identifiable {
    enum Kind { case theme, hideStyle, font }

    let id: String
    let kind: Kind
    let title: String
    let cost: Int
}

enum Rewards {
    static let storageKey = "rewards_unlocked"

    static var unlocked: Set<String> {
        Set((UserDefaults.standard.string(forKey: storageKey) ?? "").split(separator: ",").map(String.init))
    }

    static func isUnlocked(_ id: String) -> Bool {
        unlocked.contains(id)
    }

    static func unlock(_ id: String) {
        var all = unlocked
        all.insert(id)
        UserDefaults.standard.set(all.sorted().joined(separator: ","), forKey: storageKey)
    }

    static var catalog: [Reward] {
        ThemeColor.allCases.filter(\.needsPro).map { Reward(id: "theme.\($0.rawValue)", kind: .theme, title: $0.title, cost: 30) }
            + [Reward(id: "hide.stamp", kind: .hideStyle, title: L10n.string("顔をスタンプで隠す"), cost: 60)]
            + OverlayFont.allCases.filter(\.needsPro).map { Reward(id: "font.\($0.rawValue)", kind: .font, title: $0.displayName, cost: 20) }
    }

    static func spentGems() -> Int {
        let ids = unlocked
        return catalog.filter { ids.contains($0.id) }.map(\.cost).reduce(0, +)
    }
}
