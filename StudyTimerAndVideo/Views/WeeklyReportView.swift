import SwiftData
import SwiftUI

// 1週間のまとめを画像と短い文章にして、家族に LINE などで送る画面
struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Query(sort: \StudySession.date) private var sessions: [StudySession]

    @State private var week: WeeklyVlogWeek = .thisWeek
    @State private var image: UIImage?
    @State private var showVlog = false

    private let calendar = Calendar.current

    private var interval: DateInterval? { week.interval() }

    private var weekSessions: [StudySession] {
        guard let interval else { return [] }
        return sessions.filter { interval.contains($0.date) }
    }

    private var summary: WeeklyReportSummary {
        WeeklyReportSummary(sessions: weekSessions, interval: interval, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(L10n.string("週"), selection: $week) {
                        ForEach(WeeklyVlogWeek.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    WeeklyReportCard(summary: summary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                    shareButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("家族に送る"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .sheet(isPresented: $showVlog) {
                WeeklyVlogView()
            }
            .task(id: week) {
                renderImage()
            }
            .onChange(of: sessions.count) {
                renderImage()
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var shareButtons: some View {
        VStack(spacing: 10) {
            if let image {
                let picture = Image(uiImage: image)
                ShareLink(
                    item: picture,
                    message: Text(summary.message),
                    preview: SharePreview(summary.headline, image: picture)
                ) {
                    Label(L10n.string("画像で送る"), systemImage: "square.and.arrow.up")
                        .font(ReelTheme.sans(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
            }

            HStack(spacing: 10) {
                ShareLink(item: summary.message) {
                    Label(L10n.string("文章だけ送る"), systemImage: "text.bubble")
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                }
                Button {
                    showVlog = true
                } label: {
                    Label(L10n.string("Vlogも送る"), systemImage: "film.stack")
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                }
            }

            Text(L10n.string("送るのは勉強時間と教科だけです。動画は「Vlogも送る」から選んだときだけ送ります。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: WeeklyReportCard(summary: summary).frame(width: 360))
        renderer.scale = max(displayScale, 3)
        image = renderer.uiImage
    }
}

// 送る画像そのもの。画面のプレビューと同じものを画像にする
struct WeeklyReportCard: View {
    let summary: WeeklyReportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("StudyReel")
                    .font(ReelTheme.serif(15))
                    .foregroundColor(ReelTheme.accentDeep)
                Spacer()
                Text(summary.rangeText)
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
            }
            .padding(.bottom, 18)

            Text(summary.headline)
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
            Text(WeeklyVlogMaker.durationText(summary.totalSeconds))
                .font(ReelTheme.serif(38))
                .foregroundColor(ReelTheme.ink)
                .monospacedDigit()
                .padding(.top, 2)
            Text(L10n.format("%d日勉強しました", summary.studiedDays))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.ink)
                .padding(.top, 2)

            dayBars
                .padding(.top, 20)

            if !summary.subjects.isEmpty {
                VStack(spacing: 8) {
                    ForEach(summary.subjects, id: \.name) { subject in
                        HStack {
                            Text(subject.name)
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.ink)
                            Spacer()
                            Text(WeeklyVlogMaker.durationText(subject.seconds))
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 18)
            }

            if let thumbnail = summary.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 18)
            }
        }
        .padding(22)
        .background(Color.white)
    }

    private var dayBars: some View {
        let peak = max(summary.days.map(\.seconds).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(summary.days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(ReelTheme.line)
                            .frame(height: 70)
                        Capsule()
                            .fill(day.seconds > 0 ? ReelTheme.accent : Color.clear)
                            .frame(height: max(day.seconds > 0 ? 6 : 0, 70 * CGFloat(day.seconds) / CGFloat(peak)))
                    }
                    .frame(width: 14)
                    Text(day.label)
                        .font(ReelTheme.sans(10))
                        .foregroundColor(ReelTheme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// まとめに使う数字
struct WeeklyReportSummary {
    struct Day {
        let label: String
        let seconds: Int
    }

    struct Subject {
        let name: String
        let seconds: Int
    }

    let headline: String
    let rangeText: String
    let totalSeconds: Int
    let studiedDays: Int
    let days: [Day]
    let subjects: [Subject]
    let thumbnail: UIImage?

    init(sessions: [StudySession], interval: DateInterval?, calendar: Calendar) {
        let start = interval?.start ?? calendar.startOfDay(for: Date())
        let isThisWeek = interval?.contains(Date()) ?? true
        headline = isThisWeek ? L10n.string("今週の勉強") : L10n.string("先週の勉強")

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let last = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        rangeText = "\(formatter.string(from: start)) – \(formatter.string(from: last))"

        totalSeconds = sessions.reduce(0) { $0 + $1.duration }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale.current
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEEE")
        days = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let seconds = sessions
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.duration }
            return Day(label: weekdayFormatter.string(from: day), seconds: seconds)
        }
        studiedDays = days.filter { $0.seconds > 0 }.count

        var bySubject: [String: Int] = [:]
        for session in sessions {
            bySubject[session.subject, default: 0] += session.duration
        }
        subjects = bySubject
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { Subject(name: $0.key, seconds: $0.value) }

        // いちばん長く勉強した回のサムネイル（顔はモザイク済み）
        thumbnail = sessions
            .sorted { $0.duration > $1.duration }
            .lazy
            .compactMap { MediaStore.thumbnail(named: $0.thumbnailFileName) }
            .first
    }

    var message: String {
        var lines = [L10n.format("%@（%@）", headline, rangeText)]
        lines.append(L10n.format("合計 %@ · %d日", WeeklyVlogMaker.durationText(totalSeconds), studiedDays))
        if !subjects.isEmpty {
            lines.append(subjects.map { "\($0.name) \(WeeklyVlogMaker.durationText($0.seconds))" }.joined(separator: " / "))
        }
        return lines.joined(separator: "\n")
    }
}
