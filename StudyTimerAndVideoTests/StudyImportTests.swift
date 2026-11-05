import Foundation
import Testing
@testable import StudyTimerAndVideo

// ほかのアプリの CSV の読み込みと、試験日の候補
struct StudyImportTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    @Test func durations() {
        #expect(StudyImport.parseDuration("90") == 90 * 60)
        #expect(StudyImport.parseDuration("1:30") == 90 * 60)
        #expect(StudyImport.parseDuration("1:30:00") == 90 * 60)
        #expect(StudyImport.parseDuration("1時間30分") == 90 * 60)
        #expect(StudyImport.parseDuration("45分") == 45 * 60)
        #expect(StudyImport.parseDuration("1.5h") == 90 * 60)
        #expect(StudyImport.parseDuration("45 min") == 45 * 60)
        #expect(StudyImport.parseDuration("1.5") == 90 * 60)
        #expect(StudyImport.parseDuration("5400", unit: .seconds) == 5400)
        #expect(StudyImport.parseDuration("") == nil)
        #expect(StudyImport.parseDuration("abc") == nil)
    }

    // StudyReel が書き出した CSV（BOM 付き、"" で囲む）を読み直せる
    @Test func ownExport() throws {
        let csv = "\u{FEFF}\"日付\",\"開始\",\"勉強時間（分）\",\"教科\",\"タイトル\",\"教材\",\"机にいた時間（分）\",\"メモ\"\r\n"
            + "\"2026-11-03\",\"20:15\",\"95\",\"英語\",\"長文\",\"\",\"80\",\"\"\"速読\"\" の練習, 2題\"\r\n"
        let result = try StudyImport.parse(csv, calendar: calendar).get()
        #expect(result.rows.count == 1)
        let row = result.rows[0]
        #expect(row.seconds == 95 * 60)
        #expect(row.subject == "英語")
        #expect(row.title == "長文")
        #expect(row.memo == "\"速読\" の練習, 2題")
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: row.date)
        #expect(parts.year == 2026 && parts.month == 11 && parts.day == 3 && parts.hour == 20 && parts.minute == 15)
    }

    // 英語の見出しと、開始・終了だけの CSV
    @Test func startAndEnd() throws {
        let csv = "Date,Start,End,Subject\n2026/10/01,23:30,0:45,Math\n2026/10/02,,,Math\n"
        let result = try StudyImport.parse(csv, calendar: calendar).get()
        #expect(result.rows.count == 1)
        #expect(result.rows[0].seconds == 75 * 60)
        #expect(result.skipped == 1)
    }

    @Test func missingColumns() {
        let csv = "名前,点数\n田中,80\n"
        guard case .failure(.noColumns) = StudyImport.parse(csv) else {
            Issue.record("見出しが足りないときは noColumns")
            return
        }
    }

    @Test func examDates() throws {
        let kyotsu = try #require(ExamPreset.all.first { $0.title == "共通テスト 8割" })
        // 2026年は1月17日、2027年は1月16日（どちらも土曜）
        let date2026 = try #require(kyotsu.date(in: 2026, calendar: calendar))
        #expect(calendar.component(.month, from: date2026) == 1 && calendar.component(.day, from: date2026) == 17)
        let date2027 = try #require(kyotsu.date(in: 2027, calendar: calendar))
        #expect(calendar.component(.month, from: date2027) == 1 && calendar.component(.day, from: date2027) == 16)

        // 宅建は10月の第3日曜（2025年は10月19日）
        let takken = try #require(ExamPreset.all.first { $0.title == "宅建 合格" })
        let takken2025 = try #require(takken.date(in: 2025, calendar: calendar))
        #expect(calendar.component(.month, from: takken2025) == 10 && calendar.component(.day, from: takken2025) == 19)

        // 今日が試験日より後なら、次の年
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        let next = try #require(kyotsu.nextDate(after: now, calendar: calendar))
        #expect(calendar.component(.year, from: next) == 2027)
    }

    // 表紙の文字から教材を当てる
    @Test func coverText() {
        let target = UUID(), other = UUID()
        let candidates = [
            CoverMatcher.Candidate(id: target, name: "システム英単語 5訂版", cover: nil),
            CoverMatcher.Candidate(id: other, name: "青チャート 数学IA", cover: nil),
        ]
        #expect(CoverMatcher.bestByText(lines: ["駿台文庫", "システム英単語"], candidates: candidates) == target)
        #expect(CoverMatcher.bestByText(lines: ["青チャート"], candidates: candidates) == other)
        #expect(CoverMatcher.bestByText(lines: ["物理のエッセンス"], candidates: candidates) == nil)
    }
}
