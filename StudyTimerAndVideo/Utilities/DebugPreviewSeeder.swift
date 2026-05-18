import Foundation
import SwiftData

#if DEBUG
@MainActor
enum DebugPreviewSeeder {
    private static let seededKey = "debug_preview_seeded_v1"

    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        let existingSessions = (try? modelContext.fetchCount(FetchDescriptor<StudySession>())) ?? 0
        guard existingSessions == 0 else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        let subjects = [
            L10n.string("数学"),
            L10n.string("英語"),
            L10n.string("物理"),
            "Programming"
        ]

        UserDefaults.standard.set(subjects, forKey: "subjects")

        let focusTag = Tag(name: "Deep Focus", colorHex: "2B7FFF")
        let reviewTag = Tag(name: "Review", colorHex: "42B883")
        let examTag = Tag(name: "Exam Prep", colorHex: "FF8A3D")

        modelContext.insert(focusTag)
        modelContext.insert(reviewTag)
        modelContext.insert(examTag)

        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<24 {
            guard let baseDay = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            let dailySessions = sampleSessions(for: dayOffset, baseDay: baseDay, subjects: subjects, tags: [
                focusTag, reviewTag, examTag
            ])

            for session in dailySessions {
                modelContext.insert(session)
            }
        }

        let today = calendar.startOfDay(for: now)
        modelContext.insert(DailyGoal(date: today, targetDuration: 3 * 60 * 60))

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    private static func sampleSessions(for dayOffset: Int, baseDay: Date, subjects: [String], tags: [Tag]) -> [StudySession] {
        let calendar = Calendar.current

        let templates: [(hour: Int, minute: Int, duration: Int, subjectIndex: Int, tagIndex: Int)] = [
            (6, 40, 35 * 60, 1, 1),
            (19, 10, 50 * 60, 0, 0),
            (21, 0, 75 * 60, 3, 2),
            (22, 35, 40 * 60, 2, 0),
        ]

        let count: Int
        switch dayOffset % 4 {
        case 0: count = 3
        case 1: count = 2
        case 2: count = 4
        default: count = 1
        }

        return templates.prefix(count).enumerated().compactMap { index, template in
            var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
            components.hour = template.hour + (dayOffset % 2 == 0 ? 0 : index % 2)
            components.minute = template.minute

            guard let start = calendar.date(from: components) else { return nil }

            let subject = subjects[template.subjectIndex % subjects.count]
            let tag = tags[template.tagIndex % tags.count]
            let durationAdjustment = (dayOffset % 3) * 5 * 60

            return StudySession(
                date: start,
                duration: template.duration + durationAdjustment,
                subject: subject,
                tags: [tag],
                recordedAt: start
            )
        }
    }
}
#endif
