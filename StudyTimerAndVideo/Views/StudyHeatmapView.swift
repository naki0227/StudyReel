import SwiftUI

// 1年の草。列が週、行が曜日。濃いほど長く勉強した日
struct StudyHeatmapGrid: View {
    let year: StudyYear
    var cell: CGFloat = 9
    var gap: CGFloat = 2

    private let calendar = Calendar.current

    var body: some View {
        let weeks = columns
        Canvas { context, _ in
            for (column, week) in weeks.enumerated() {
                for (row, day) in week.enumerated() {
                    guard let day else { continue }
                    let rect = CGRect(x: CGFloat(column) * (cell + gap), y: CGFloat(row) * (cell + gap), width: cell, height: cell)
                    let level = StudyYear.level(year.seconds[day] ?? 0)
                    context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.22), with: .color(Self.color(level)))
                }
            }
        }
        .frame(width: CGFloat(weeks.count) * (cell + gap) - gap, height: 7 * (cell + gap) - gap)
        .accessibilityElement()
        .accessibilityLabel(L10n.format("%d年は%d日勉強しました。合計%@", year.year, year.studyDays, WeeklyVlogMaker.durationText(year.totalSeconds)))
    }

    static func color(_ level: Int) -> Color {
        switch level {
        case 0: return ReelTheme.line
        case 1: return ReelTheme.accent.opacity(0.35)
        case 2: return ReelTheme.accent.opacity(0.6)
        case 3: return ReelTheme.accent
        default: return ReelTheme.accentDeep
        }
    }

    // 週ごとに7日（週の初めの曜日から）。年の外の日と、まだ来ていない日は nil
    private var columns: [[Date?]] {
        let today = calendar.startOfDay(for: Date())
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: year.start)?.start ?? year.start
        var result: [[Date?]] = []
        var weekStart = firstWeek
        while weekStart < year.end && weekStart <= today {
            var week: [Date?] = []
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                week.append(day >= year.start && day < year.end && day <= today ? day : nil)
            }
            result.append(week)
            weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? year.end
        }
        return result
    }
}

// 統計の「年」に出す。勉強した日数を主役にして、連続日数は添えるだけ
struct StudyHeatmapSection: View {
    let year: StudyYear
    @State private var shareImage: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.format("%d日 勉強した", year.studyDays))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
                if year.studyDays > 0 {
                    if let shareImage {
                        ShareLink(item: Image(uiImage: shareImage), preview: SharePreview(L10n.string("1年の記録"), image: Image(uiImage: shareImage))) {
                            Label(L10n.string("カードで共有"), systemImage: "square.and.arrow.up")
                                .font(ReelTheme.sans(12))
                                .foregroundColor(ReelTheme.accentDeep)
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                StudyHeatmapGrid(year: year, cell: 11, gap: 3)
                    .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.trailing)
            HStack(spacing: 4) {
                Text(L10n.string("少ない"))
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2).fill(StudyHeatmapGrid.color(level)).frame(width: 9, height: 9)
                }
                Text(L10n.string("多い"))
                Spacer()
                if year.longestStreak > 1 {
                    Text(L10n.format("いちばん長く続いたのは%d日", year.longestStreak))
                }
            }
            .font(ReelTheme.sans(10))
            .foregroundColor(ReelTheme.secondary)
        }
        .task(id: "\(year.year)-\(year.studyDays)-\(year.totalSeconds)") {
            render()
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: StudyYearCard(year: year).frame(width: 360, height: 640))
        renderer.scale = max(displayScale, 3)
        shareImage = renderer.uiImage
    }
}

// 共有する1年のカード（縦長 1080×1920）。顔は写らない
struct StudyYearCard: View {
    let year: StudyYear

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("StudyReel")
                    .font(ReelTheme.serif(15))
                    .foregroundColor(ReelTheme.accentDeep)
                Spacer()
                Text(String(year.year))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
            }
            Spacer()
            Text(L10n.string("今年 勉強した日"))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
            Text(L10n.format("%d日", year.studyDays))
                .font(ReelTheme.serif(54))
                .foregroundColor(ReelTheme.ink)
                .monospacedDigit()
            Text(L10n.format("合計 %@", WeeklyVlogMaker.durationText(year.totalSeconds)))
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.ink)
                .padding(.top, 2)
            Spacer()
            // 53週を横幅に収める
            StudyHeatmapGrid(year: year, cell: 4.4, gap: 1.3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            if year.longestStreak > 1 {
                Text(L10n.format("いちばん長く続いたのは%d日", year.longestStreak))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            }
            Text(L10n.string("#勉強垢 #勉強記録 #StudyReel"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
                .padding(.top, 6)
        }
        .padding(26)
        .background(Color.white)
    }
}
