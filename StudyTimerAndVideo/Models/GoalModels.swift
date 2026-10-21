import Foundation
import SwiftData

// 長い目標（「TOEIC 800点」「英検2級 合格」など）。期日までの D-day と、勉強時間・過去問の点数で進み具合を見る
@Model
class StudyGoal {
    var id: UUID
    var title: String
    var deadline: Date
    // 点数で目指すときの目標点と満点（合格だけを目指すときは nil）
    var targetScore: Int?
    var maxScore: Int?
    // 目標の勉強時間（時間）
    var targetHours: Int?
    // 使う教材（StudyMaterial.id をカンマでつないだもの）
    var materialIDsRaw: String
    // 共有カードに出すひとこと
    var note: String
    var createdAt: Date
    // 達成したと記録した日と、本番の点数
    var achievedAt: Date?
    var achievedScore: Int?
    // 新しい目標に切り替えたら、前の目標はここに日付が入る
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        deadline: Date,
        targetScore: Int? = nil,
        maxScore: Int? = nil,
        targetHours: Int? = nil,
        materialIDs: [UUID] = [],
        note: String = "",
        createdAt: Date = Date(),
        achievedAt: Date? = nil,
        achievedScore: Int? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.targetScore = targetScore
        self.maxScore = maxScore
        self.targetHours = targetHours
        self.materialIDsRaw = materialIDs.map(\.uuidString).joined(separator: ",")
        self.note = note
        self.createdAt = createdAt
        self.achievedAt = achievedAt
        self.achievedScore = achievedScore
        self.archivedAt = archivedAt
    }

    var materialIDs: [UUID] {
        get { materialIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) } }
        set { materialIDsRaw = newValue.map(\.uuidString).joined(separator: ",") }
    }

    var isAchieved: Bool { achievedAt != nil }

    // 期日まであと何日か（当日は 0、過ぎたらマイナス）
    func daysLeft(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: deadline)).day ?? 0
    }

    // 宣言してから何日目か（宣言した日が 1 日目）
    func dayNumber(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: createdAt), to: calendar.startOfDay(for: date)).day ?? 0) + 1
    }

    // 「D-56」「D-day」「D+3」
    func dDayText(from date: Date = Date()) -> String {
        let left = daysLeft(from: date)
        if left == 0 { return "D-day" }
        return left > 0 ? "D-\(left)" : "D+\(-left)"
    }
}

// 過去問・模試の1回分の結果
@Model
class PastPaperResult {
    var id: UUID
    // 「公式問題集10 Test 1」「2023年度 第1回」など。同じ名前のものを「同じ問題」としてまとめる
    var paperName: String
    var date: Date
    var score: Int?
    var maxScore: Int?
    // 合否（PaperOutcome の rawValue）
    var outcomeRaw: String
    var durationSeconds: Int?
    var memo: String
    // 大問ごとの点数（[ScorePart] の JSON）
    var partsJSON: String
    var materialID: UUID?

    init(
        id: UUID = UUID(),
        paperName: String,
        date: Date = Date(),
        score: Int? = nil,
        maxScore: Int? = nil,
        outcome: PaperOutcome = .none,
        durationSeconds: Int? = nil,
        memo: String = "",
        parts: [ScorePart] = [],
        materialID: UUID? = nil
    ) {
        self.id = id
        self.paperName = paperName
        self.date = date
        self.score = score
        self.maxScore = maxScore
        self.outcomeRaw = outcome.rawValue
        self.durationSeconds = durationSeconds
        self.memo = memo
        self.partsJSON = ScorePart.encode(parts)
        self.materialID = materialID
    }

    var outcome: PaperOutcome {
        get { PaperOutcome(rawValue: outcomeRaw) ?? .none }
        set { outcomeRaw = newValue.rawValue }
    }

    var parts: [ScorePart] {
        get { ScorePart.decode(partsJSON) }
        set { partsJSON = ScorePart.encode(newValue) }
    }

    // 満点に対する割合（0〜1）
    var ratio: Double? {
        guard let score, let maxScore, maxScore > 0 else { return nil }
        return Double(score) / Double(maxScore)
    }
}

enum PaperOutcome: String, CaseIterable, Identifiable {
    case none
    case passed
    case failed

    var id: String { rawValue }
}

// 大問（パート）ひとつ分の点数
struct ScorePart: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var score: Int?
    var maxScore: Int?

    static func encode(_ parts: [ScorePart]) -> String {
        guard !parts.isEmpty, let data = try? JSONEncoder().encode(parts) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ json: String) -> [ScorePart] {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ScorePart].self, from: data)) ?? []
    }
}

// 同じ問題を何回か解いたときのまとまり
struct PaperSeries: Identifiable {
    let name: String
    // 古い順
    let results: [PastPaperResult]

    var id: String { name }

    var first: PastPaperResult? { results.first }
    var latest: PastPaperResult? { results.last }

    // はじめから何点伸びたか（点数のある回が2回以上のとき）
    var gain: Int? {
        let scored = results.compactMap(\.score)
        guard scored.count >= 2, let first = scored.first, let last = scored.last else { return nil }
        return last - first
    }

    static func group(_ results: [PastPaperResult]) -> [PaperSeries] {
        let grouped = Dictionary(grouping: results) { $0.paperName.trimmingCharacters(in: .whitespacesAndNewlines) }
        return grouped
            .map { PaperSeries(name: $0.key, results: $0.value.sorted { $0.date < $1.date }) }
            // 最後に解いた日が新しい順
            .sorted { ($0.latest?.date ?? .distantPast) > ($1.latest?.date ?? .distantPast) }
    }
}

// 目標の進み具合（ホームと共有カードで使う）
struct GoalProgress {
    let goal: StudyGoal
    let studiedSeconds: Int
    let bestScore: Int?
    let firstScore: Int?
    let paperCount: Int
    let studyDays: Int
    let streakDays: Int
    // 直近7日（古い順）に勉強したか
    let lastSevenDays: [Bool]

    init(goal: StudyGoal, sessions: [StudySession], papers: [PastPaperResult], now: Date = Date(), calendar: Calendar = .current) {
        self.goal = goal
        let start = calendar.startOfDay(for: goal.createdAt)
        let since = sessions.filter { $0.date >= start }
        studiedSeconds = since.reduce(0) { $0 + $1.duration }

        // 目標と満点がそろっている過去問だけで点数を比べる。満点を書いていない回は、目標と同じ満点とみなす
        let comparable = papers
            .filter { $0.score != nil && (goal.maxScore == nil || $0.maxScore == nil || $0.maxScore == goal.maxScore) }
            .sorted { $0.date < $1.date }
        bestScore = comparable.compactMap(\.score).max()
        firstScore = comparable.first?.score
        paperCount = papers.filter { $0.date >= start }.count

        let days = Set(since.map { calendar.startOfDay(for: $0.date) })
        studyDays = days.count
        var streak = 0
        var day = calendar.startOfDay(for: now)
        // 今日まだ勉強していなくても、昨日まで続いていれば連続とみなす
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        streakDays = streak
        let today = calendar.startOfDay(for: now)
        let allDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        lastSevenDays = (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return allDays.contains(date)
        }
    }

    var studiedHours: Double { Double(studiedSeconds) / 3600 }

    var hoursRatio: Double? {
        guard let target = goal.targetHours, target > 0 else { return nil }
        return min(studiedHours / Double(target), 1)
    }

    var scoreRatio: Double? {
        guard let target = goal.targetScore, target > 0, let bestScore else { return nil }
        return min(Double(bestScore) / Double(target), 1)
    }
}
