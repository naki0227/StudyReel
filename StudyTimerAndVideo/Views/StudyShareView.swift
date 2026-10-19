import SwiftData
import SwiftUI

// 今日・今週・先週の勉強を画像と短い文章にして、勉強垢のグループや SNS に共有する画面
struct StudyShareView: View {
    static let hashtagKey = "share_adds_hashtags"
    static let photoKey = "share_includes_photo"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Query(sort: \StudySession.date) private var sessions: [StudySession]
    @AppStorage(hashtagKey) private var addsHashtags = true
    @AppStorage(photoKey) private var includesPhoto = true

    @State private var period: SharePeriod = .today
    @State private var image: UIImage?
    @State private var showVlog = false

    private var summary: StudyShareSummary {
        StudyShareSummary(sessions: sessions, period: period, includesPhoto: includesPhoto)
    }

    private var message: String {
        summary.message(addsHashtags: addsHashtags)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(L10n.string("期間"), selection: $period) {
                        ForEach(SharePeriod.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    StudyShareCard(summary: summary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                    options
                    shareButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("共有する"))
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
            .task(id: period) {
                renderImage()
            }
            .onChange(of: includesPhoto) {
                renderImage()
            }
            .onChange(of: sessions.count) {
                renderImage()
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var options: some View {
        ReelCard {
            VStack(spacing: 0) {
                Toggle(L10n.string("写真を入れる"), isOn: $includesPhoto)
                    .font(ReelTheme.sans(14))
                    .padding(.vertical, 10)
                Divider()
                Toggle(L10n.string("ハッシュタグをつける"), isOn: $addsHashtags)
                    .font(ReelTheme.sans(14))
                    .padding(.vertical, 10)
            }
            .padding(.horizontal, 16)
            .tint(ReelTheme.accent)
            .foregroundColor(ReelTheme.ink)
        }
    }

    private var shareButtons: some View {
        VStack(spacing: 10) {
            if let image {
                let picture = Image(uiImage: image)
                ShareLink(
                    item: picture,
                    message: Text(message),
                    preview: SharePreview(summary.headline, image: picture)
                ) {
                    Label(L10n.string("画像で共有"), systemImage: "square.and.arrow.up")
                        .font(ReelTheme.sans(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
            }

            HStack(spacing: 10) {
                ShareLink(item: message) {
                    Label(L10n.string("文章だけ"), systemImage: "text.bubble")
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                }
                Button {
                    showVlog = true
                } label: {
                    Label(L10n.string("Vlogを共有"), systemImage: "film.stack")
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                }
            }

            Text(L10n.string("写真は顔にモザイクがかかったサムネイルです。動画は「Vlogを共有」から選んだときだけ送ります。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: StudyShareCard(summary: summary).frame(width: 360))
        renderer.scale = max(displayScale, 3)
        image = renderer.uiImage
    }
}

enum SharePeriod: String, CaseIterable, Identifiable {
    case today
    case thisWeek
    case lastWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return L10n.string("今日")
        case .thisWeek: return L10n.string("今週")
        case .lastWeek: return L10n.string("先週")
        }
    }

    var headline: String {
        switch self {
        case .today: return L10n.string("今日の勉強")
        case .thisWeek: return L10n.string("今週の勉強")
        case .lastWeek: return L10n.string("先週の勉強")
        }
    }

    func interval(calendar: Calendar = .current, now: Date = Date()) -> DateInterval? {
        switch self {
        case .today: return calendar.dateInterval(of: .day, for: now)
        case .thisWeek: return WeeklyVlogWeek.thisWeek.interval(calendar: calendar, now: now)
        case .lastWeek: return WeeklyVlogWeek.lastWeek.interval(calendar: calendar, now: now)
        }
    }
}

// 共有する画像そのもの。画面のプレビューと同じものを画像にする
struct StudyShareCard: View {
    let summary: StudyShareSummary

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
            Text(summary.detailLine)
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.ink)
                .padding(.top, 2)

            if !summary.days.isEmpty {
                dayBars
                    .padding(.top, 20)
            }

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

// 共有に使う数字
struct StudyShareSummary {
    struct Day {
        let label: String
        let seconds: Int
    }

    struct Subject {
        let name: String
        let seconds: Int
    }

    let period: SharePeriod
    let headline: String
    let rangeText: String
    let totalSeconds: Int
    let sessionCount: Int
    let studiedDays: Int
    // 週のときだけ曜日ごとの棒を出す
    let days: [Day]
    let subjects: [Subject]
    let thumbnail: UIImage?

    init(sessions allSessions: [StudySession], period: SharePeriod, includesPhoto: Bool, calendar: Calendar = .current) {
        self.period = period
        let interval = period.interval(calendar: calendar)
        let sessions = interval.map { range in allSessions.filter { range.contains($0.date) } } ?? []
        let start = interval?.start ?? calendar.startOfDay(for: Date())
        headline = period.headline

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if period == .today {
            formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
            rangeText = formatter.string(from: start)
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            let last = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            rangeText = "\(formatter.string(from: start)) – \(formatter.string(from: last))"
        }

        totalSeconds = sessions.reduce(0) { $0 + $1.duration }
        sessionCount = sessions.count

        if period == .today {
            days = []
            studiedDays = sessions.isEmpty ? 0 : 1
        } else {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale.current
            weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEEE")
            let week = (0..<7).map { offset -> Day in
                let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                let seconds = sessions
                    .filter { calendar.isDate($0.date, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.duration }
                return Day(label: weekdayFormatter.string(from: day), seconds: seconds)
            }
            days = week
            studiedDays = week.filter { $0.seconds > 0 }.count
        }

        var bySubject: [String: Int] = [:]
        for session in sessions {
            bySubject[session.subject, default: 0] += session.duration
        }
        subjects = bySubject
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { Subject(name: $0.key, seconds: $0.value) }

        // いちばん長く勉強した回のサムネイル（顔はモザイク済み）
        thumbnail = includesPhoto ? sessions
            .sorted { $0.duration > $1.duration }
            .lazy
            .compactMap { MediaStore.thumbnail(named: $0.thumbnailFileName) }
            .first : nil
    }

    var detailLine: String {
        period == .today
            ? L10n.format("%d回 記録しました", sessionCount)
            : L10n.format("%d日勉強しました", studiedDays)
    }

    func message(addsHashtags: Bool) -> String {
        var lines = [L10n.format("%@（%@）", headline, rangeText)]
        if period == .today {
            lines.append(L10n.format("合計 %@", WeeklyVlogMaker.durationText(totalSeconds)))
        } else {
            lines.append(L10n.format("合計 %@ · %d日", WeeklyVlogMaker.durationText(totalSeconds), studiedDays))
        }
        if !subjects.isEmpty {
            lines.append(subjects.map { "\($0.name) \(WeeklyVlogMaker.durationText($0.seconds))" }.joined(separator: " / "))
        }
        if addsHashtags {
            lines.append(L10n.string("#勉強垢 #勉強記録 #StudyReel"))
        }
        return lines.joined(separator: "\n")
    }
}
