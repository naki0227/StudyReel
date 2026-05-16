import Foundation

enum StudyInsights {
    static func overlappingSession(in sessions: [StudySession], start: Date, duration: Int, excludingID: UUID? = nil) -> StudySession? {
        guard duration > 0 else { return nil }

        let end = start.addingTimeInterval(TimeInterval(duration))
        return sessions.first { session in
            guard session.duration > 0 else { return false }
            if let excludingID, session.id == excludingID { return false }

            let sessionEnd = session.date.addingTimeInterval(TimeInterval(session.duration))
            return start < sessionEnd && end > session.date
        }
    }

    static func inferredSubject(from sessions: [StudySession], now: Date = Date()) -> String? {
        guard !sessions.isEmpty else { return nil }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        var scores: [String: Int] = [:]

        for (index, session) in sessions.prefix(12).enumerated() {
            let recentWeight = max(1, 12 - index)
            scores[session.subject, default: 0] += recentWeight

            let hourDistance = abs(calendar.component(.hour, from: session.date) - currentHour)
            if hourDistance == 0 {
                scores[session.subject, default: 0] += 10
            } else if hourDistance == 1 {
                scores[session.subject, default: 0] += 6
            }

            if calendar.isDateInToday(session.date) {
                scores[session.subject, default: 0] += 3
            }
        }

        return scores.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }.first?.key
    }

    static func focusSubjectOptions(from sessions: [StudySession], selected: String?, inferred: String?) -> [String] {
        var seen = Set<String>()
        let candidates = [selected, inferred] + sessions.prefix(5).map(\.subject)
        return candidates
            .compactMap { $0 }
            .filter { seen.insert($0).inserted }
            .prefix(4)
            .map { $0 }
    }

    static func mostCommonStartHourText(for sessions: [StudySession]) -> String {
        let grouped = Dictionary(grouping: sessions) { Calendar.current.component(.hour, from: $0.date) }
        guard let best = grouped.max(by: { $0.value.count < $1.value.count })?.key else {
            return "--:--"
        }
        return String(format: "%02d:00", best)
    }

    static func averageDurationSeconds(for sessions: [StudySession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.duration).reduce(0, +) / sessions.count
    }

    static func sessionsNearCurrentHour(_ sessions: [StudySession], now: Date = Date()) -> Int {
        let currentHour = Calendar.current.component(.hour, from: now)
        return sessions.filter { abs(Calendar.current.component(.hour, from: $0.date) - currentHour) <= 1 }.count
    }

    static func strongestHourText(for sessions: [StudySession]) -> String {
        mostCommonStartHourText(for: sessions)
    }

    static func preferredReminderDate(for sessions: [StudySession], now: Date = Date()) -> Date? {
        let relevantSessions = recentSessionsForReminder(from: sessions)
        guard !relevantSessions.isEmpty else { return nil }

        let calendar = Calendar.current
        let todayTotal = totalStudySeconds(on: now, from: relevantSessions)
        let averageDaily = averageDailyStudySeconds(for: relevantSessions)
        guard let averageStartMinute = averageStartMinuteOfDay(for: relevantSessions) else {
            return nil
        }

        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let expectedByNow = averageCumulativeStudySeconds(atMinuteOfDay: currentMinute, sessions: relevantSessions)
        let expectedByStart = averageCumulativeStudySeconds(atMinuteOfDay: averageStartMinute, sessions: relevantSessions)

        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = averageStartMinute / 60
        todayComponents.minute = averageStartMinute % 60

        guard let averageStartToday = calendar.date(from: todayComponents) else {
            return nil
        }

        let isBehindToday = todayTotal < max(expectedByNow, expectedByStart)
        if averageDaily > 0, todayTotal >= averageDaily {
            return calendar.date(byAdding: .day, value: 1, to: averageStartToday)
        }

        if averageStartToday > now.addingTimeInterval(30 * 60) {
            return isBehindToday ? averageStartToday : calendar.date(byAdding: .day, value: 1, to: averageStartToday)
        }

        if isBehindToday {
            return now.addingTimeInterval(45 * 60)
        }

        return calendar.date(byAdding: .day, value: 1, to: averageStartToday)
    }

    static func quietReminderBody(for sessions: [StudySession], now: Date = Date()) -> String {
        let relevantSessions = recentSessionsForReminder(from: sessions)
        let averageDaily = averageDailyStudySeconds(for: relevantSessions)
        let todayTotal = totalStudySeconds(on: now, from: sessions)
        let shortfall = max(0, averageDaily - todayTotal)

        if shortfall > 0 {
            return L10n.format("今日は平均まであと %@", compactDuration(shortfall))
        }

        guard preferredReminderDate(for: sessions, now: now) != nil else {
            return L10n.string("最近のあなたはこの時間によく集中しています")
        }
        return L10n.string("最近のあなたはこの時間によく集中しています")
    }

    static func averageDailyStudySeconds(for sessions: [StudySession]) -> Int {
        let dailyTotals = groupedSessionsByDay(from: sessions).values
            .map { $0.map(\.duration).reduce(0, +) }
            .filter { $0 > 0 }

        guard !dailyTotals.isEmpty else { return 0 }
        return dailyTotals.reduce(0, +) / dailyTotals.count
    }

    static func subjectWeekComparison(for sessions: [StudySession], subject: String, now: Date = Date()) -> (thisWeek: Int, lastWeek: Int)? {
        let calendar = Calendar.current
        let subjectSessions = sessions.filter { $0.subject == subject }
        guard !subjectSessions.isEmpty else { return nil }

        let thisWeek = subjectSessions
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .map(\.duration)
            .reduce(0, +)

        guard let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else {
            return (thisWeek, 0)
        }

        let lastWeek = subjectSessions
            .filter { calendar.isDate($0.date, equalTo: lastWeekDate, toGranularity: .weekOfYear) }
            .map(\.duration)
            .reduce(0, +)

        return (thisWeek, lastWeek)
    }

    static func weeklyComparisonText(for sessions: [StudySession], subject: String) -> String {
        guard let comparison = subjectWeekComparison(for: sessions, subject: subject) else {
            return L10n.string("比較データなし")
        }

        if comparison.lastWeek == 0 {
            if comparison.thisWeek == 0 {
                return L10n.string("比較データなし")
            }
            return L10n.string("今週から記録が増えています")
        }

        let diff = comparison.thisWeek - comparison.lastWeek
        let ratio = Int((Double(diff) / Double(comparison.lastWeek)) * 100)

        if diff == 0 {
            return L10n.string("先週と同じペース")
        } else if diff > 0 {
            return L10n.format("先週比 +%d%%", ratio)
        } else {
            return L10n.format("先週比 %d%%", ratio)
        }
    }

    static func pastYouMessages(
        sessions: [StudySession],
        startedAt: Date,
        elapsed: Int,
        activeFocusSubject: String?
    ) -> [String] {
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: startedAt) * 60 + calendar.component(.minute, from: startedAt)
        let comparableSessions = sessions.filter { $0.duration > 0 }
        let comparableSubjectSessions = activeFocusSubject.map { subject in
            comparableSessions.filter { $0.subject == subject }
        } ?? []

        let startedAroundNowCount = comparableSessions.filter {
            let minutes = calendar.component(.hour, from: $0.date) * 60 + calendar.component(.minute, from: $0.date)
            return abs(minutes - currentMinutes) <= 30
        }.count

        let subjectStartedAroundNowCount = comparableSubjectSessions.filter {
            let minutes = calendar.component(.hour, from: $0.date) * 60 + calendar.component(.minute, from: $0.date)
            return abs(minutes - currentMinutes) <= 30
        }.count

        let alreadyStoppedCount = comparableSessions.filter { $0.duration < elapsed }.count
        let stillGoingCount = comparableSessions.filter { $0.duration >= elapsed }.count
        let subjectStillGoingCount = comparableSubjectSessions.filter { $0.duration >= elapsed }.count

        let nearestLongerSession = comparableSessions.map(\.duration).filter { $0 > elapsed }.min()
        let nearestLongerSubjectSession = comparableSubjectSessions.map(\.duration).filter { $0 > elapsed }.min()

        var messages: [String] = []
        messages.append(L10n.format("この時間帯、過去のあなた %d 人が始めています", startedAroundNowCount))
        messages.append(L10n.format("ここまでで %d 人はもう終了、%d 人はまだ継続していました", alreadyStoppedCount, stillGoingCount))

        if let activeFocusSubject {
            messages.append(L10n.format("「%@」では、この時間に %d 回始めていて、%d 回は今も継続圏です", activeFocusSubject, subjectStartedAroundNowCount, subjectStillGoingCount))
        }

        if let nearestLongerSubjectSession, let activeFocusSubject {
            messages.append(L10n.format("「%@」の過去平均圏までは、あと %@", activeFocusSubject, compactDuration(nearestLongerSubjectSession - elapsed)))
        } else if let nearestLongerSession {
            messages.append(L10n.format("あと %@ で、次の過去記録を超えます", compactDuration(nearestLongerSession - elapsed)))
        } else if elapsed > 0 {
            messages.append(L10n.string("ここまで続けたあなたは、過去の自分をもう超えています"))
        }

        return messages
    }

    static func compactDuration(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let minutes = safeSeconds / 60
        let remainingSeconds = safeSeconds % 60

        if safeSeconds >= 3600 {
            let hours = safeSeconds / 3600
            let mins = (safeSeconds % 3600) / 60
            return L10n.format("%d時間%d分", hours, mins)
        }
        if minutes > 0 {
            return L10n.format("%d分%d秒", minutes, remainingSeconds)
        }
        return L10n.format("%d秒", remainingSeconds)
    }

    private static func recentSessionsForReminder(from sessions: [StudySession]) -> [StudySession] {
        Array(sessions.filter { $0.duration > 0 }.prefix(30))
    }

    private static func groupedSessionsByDay(from sessions: [StudySession]) -> [Date: [StudySession]] {
        let calendar = Calendar.current
        return Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
    }

    private static func averageStartMinuteOfDay(for sessions: [StudySession]) -> Int? {
        let grouped = groupedSessionsByDay(from: sessions)
        let dailyStarts = grouped.values.compactMap { daySessions -> Int? in
            guard let first = daySessions.map(\.date).min() else { return nil }
            let calendar = Calendar.current
            return calendar.component(.hour, from: first) * 60 + calendar.component(.minute, from: first)
        }

        guard !dailyStarts.isEmpty else { return nil }
        return dailyStarts.reduce(0, +) / dailyStarts.count
    }

    private static func averageCumulativeStudySeconds(atMinuteOfDay minuteOfDay: Int, sessions: [StudySession]) -> Int {
        let grouped = groupedSessionsByDay(from: sessions)
        let cumulativeValues = grouped.values.compactMap { daySessions -> Int? in
            let total = cumulativeStudySeconds(atMinuteOfDay: minuteOfDay, sessions: daySessions)
            return total > 0 ? total : nil
        }

        guard !cumulativeValues.isEmpty else { return 0 }
        return cumulativeValues.reduce(0, +) / cumulativeValues.count
    }

    private static func cumulativeStudySeconds(atMinuteOfDay minuteOfDay: Int, sessions: [StudySession]) -> Int {
        let cutoff = minuteOfDay * 60
        let calendar = Calendar.current

        return sessions.reduce(0) { partialResult, session in
            let startMinute = calendar.component(.hour, from: session.date) * 60 + calendar.component(.minute, from: session.date)
            let startSecond = startMinute * 60
            let studiedUntilCutoff = max(0, min(session.duration, cutoff - startSecond))
            return partialResult + studiedUntilCutoff
        }
    }

    private static func totalStudySeconds(on date: Date, from sessions: [StudySession]) -> Int {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map(\.duration)
            .reduce(0, +)
    }
}
