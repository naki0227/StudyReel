import SwiftData
import SwiftUI

// 勉強の記録を画像と短い文章にして、勉強垢のグループや SNS に共有する画面
//  - 期間：今日・今週・先週
//  - 教材：ひとつの教材にかけた時間（やり終えたら「終えました」）
//  - 教科：今月・これまでの、ひとつの教科の時間
struct StudyShareView: View {
    static let hashtagKey = "share_adds_hashtags"
    static let photoKey = "share_includes_photo"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Query(sort: \StudySession.date) private var sessions: [StudySession]
    @Query(sort: \StudyMaterial.createdAt, order: .reverse) private var materials: [StudyMaterial]
    @AppStorage(hashtagKey) private var addsHashtags = true
    @AppStorage(photoKey) private var includesPhoto = true

    @State private var kind: ShareKind
    @State private var period: SharePeriod = .today
    @State private var materialID: UUID?
    @State private var subject = ""
    @State private var subjectRange: SubjectShareRange = .thisMonth
    @State private var image: UIImage?
    @State private var showVlog = false

    init(initialMaterial: StudyMaterial? = nil) {
        _kind = State(initialValue: initialMaterial == nil ? .period : .material)
        _materialID = State(initialValue: initialMaterial?.id)
    }

    private var summary: StudyShareSummary {
        StudyShareSummary(sessions: sessions, period: period, includesPhoto: includesPhoto)
    }

    private var selectedMaterial: StudyMaterial? {
        materials.first { $0.id == materialID } ?? materials.first
    }

    private var materialSummary: MaterialShareSummary? {
        selectedMaterial.map { MaterialShareSummary(material: $0, sessions: sessions, includesPhoto: includesPhoto) }
    }

    // 勉強時間の長い順
    private var subjects: [String] {
        var totals: [String: Int] = [:]
        for session in sessions {
            totals[session.subject, default: 0] += session.duration
        }
        return totals.sorted { $0.value > $1.value }.map(\.key)
    }

    private var selectedSubject: String? {
        subjects.contains(subject) ? subject : subjects.first
    }

    private var subjectSummary: SubjectShareSummary? {
        selectedSubject.map {
            SubjectShareSummary(subject: $0, range: subjectRange, sessions: sessions, materials: materials, includesPhoto: includesPhoto)
        }
    }

    private var message: String? {
        switch kind {
        case .period: return summary.message(addsHashtags: addsHashtags)
        case .material: return materialSummary?.message(addsHashtags: addsHashtags)
        case .subject: return subjectSummary?.message(addsHashtags: addsHashtags)
        }
    }

    private var headline: String {
        switch kind {
        case .period: return summary.headline
        case .material: return materialSummary?.material.name ?? L10n.string("教材")
        case .subject: return subjectSummary?.headline ?? L10n.string("教科")
        }
    }

    // 何か変わったら画像を作り直す
    private var renderKey: String {
        [
            kind.rawValue, period.rawValue, materialID?.uuidString ?? "", subject, subjectRange.rawValue,
            String(includesPhoto), String(sessions.count), String(materials.count),
            selectedMaterial.map { "\($0.name)\($0.finishedAt?.timeIntervalSince1970 ?? 0)" } ?? ""
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(L10n.string("共有するもの"), selection: $kind) {
                        ForEach(ShareKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    selector

                    if message == nil {
                        emptyState
                    } else {
                        card
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                        options
                        shareButtons
                    }
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
            .task(id: renderKey) {
                renderImage()
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    // 種類ごとの選び方
    @ViewBuilder
    private var selector: some View {
        switch kind {
        case .period:
            Picker(L10n.string("期間"), selection: $period) {
                ForEach(SharePeriod.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
        case .material:
            if !materials.isEmpty {
                Menu {
                    ForEach(materials) { item in
                        Button {
                            materialID = item.id
                        } label: {
                            if item.id == selectedMaterial?.id {
                                Label(item.name, systemImage: "checkmark")
                            } else {
                                Text(item.name)
                            }
                        }
                    }
                } label: {
                    menuLabel(selectedMaterial?.name ?? L10n.string("教材を選ぶ"))
                }
            }
        case .subject:
            if !subjects.isEmpty {
                VStack(spacing: 10) {
                    Menu {
                        ForEach(subjects, id: \.self) { item in
                            Button {
                                subject = item
                            } label: {
                                if item == selectedSubject {
                                    Label(item, systemImage: "checkmark")
                                } else {
                                    Text(item)
                                }
                            }
                        }
                    } label: {
                        menuLabel(selectedSubject ?? L10n.string("教科を選ぶ"))
                    }
                    Picker(L10n.string("期間"), selection: $subjectRange) {
                        ForEach(SubjectShareRange.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func menuLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(ReelTheme.sans(15))
                .foregroundColor(ReelTheme.ink)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ReelTheme.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    @ViewBuilder
    private var card: some View {
        switch kind {
        case .period:
            StudyShareCard(summary: summary)
        case .material:
            if let materialSummary {
                MaterialShareCard(summary: materialSummary)
            }
        case .subject:
            if let subjectSummary {
                SubjectShareCard(summary: subjectSummary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: kind == .material ? "books.vertical" : "chart.bar")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(ReelTheme.accentDeep)
            Text(kind == .material ? L10n.string("まだ教材がありません") : L10n.string("まだ記録がありません"))
                .font(ReelTheme.serif(18))
                .foregroundColor(ReelTheme.ink)
            if kind == .material {
                Text(L10n.string("録画を始めるときに教材を選ぶと、ここで共有できます。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
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
        let text = message ?? ""
        return VStack(spacing: 10) {
            if let image {
                let picture = Image(uiImage: image)
                ShareLink(
                    item: picture,
                    message: Text(text),
                    preview: SharePreview(headline, image: picture)
                ) {
                    Label(L10n.string("画像で共有"), systemImage: "square.and.arrow.up")
                        .font(ReelTheme.sans(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
            }

            HStack(spacing: 10) {
                ShareLink(item: text) {
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
        guard message != nil else {
            image = nil
            return
        }
        let renderer = ImageRenderer(content: card.frame(width: 360))
        renderer.scale = max(displayScale, 3)
        image = renderer.uiImage
    }
}

enum ShareKind: String, CaseIterable, Identifiable {
    case period
    case material
    case subject

    var id: String { rawValue }

    var title: String {
        switch self {
        case .period: return L10n.string("期間")
        case .material: return L10n.string("教材")
        case .subject: return L10n.string("教科")
        }
    }
}

enum SubjectShareRange: String, CaseIterable, Identifiable {
    case thisMonth
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: return L10n.string("今月")
        case .allTime: return L10n.string("これまで")
        }
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

// いちばん長く勉強した回のサムネイル（顔はモザイク済み）
private func longestThumbnail(_ sessions: [StudySession]) -> UIImage? {
    sessions
        .sorted { $0.duration > $1.duration }
        .lazy
        .compactMap { MediaStore.thumbnail(named: $0.thumbnailFileName) }
        .first
}

private func shareRangeText(from start: Date?, to end: Date?) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.setLocalizedDateFormatFromTemplate("yMMMd")
    guard let start else { return "" }
    let last = end ?? start
    if Calendar.current.isDate(start, inSameDayAs: last) {
        return formatter.string(from: start)
    }
    return "\(formatter.string(from: start)) – \(formatter.string(from: last))"
}

// MARK: - 教材

struct MaterialShareSummary {
    let material: StudyMaterial
    let totals: StudyTotals
    let rangeText: String
    let thumbnail: UIImage?

    init(material: StudyMaterial, sessions allSessions: [StudySession], includesPhoto: Bool) {
        self.material = material
        let sessions = allSessions.filter { $0.materialID == material.id }
        totals = StudyTotals(sessions: sessions)
        rangeText = shareRangeText(from: totals.firstDate ?? material.createdAt, to: material.finishedAt ?? totals.lastDate)
        thumbnail = includesPhoto ? longestThumbnail(sessions) : nil
    }

    func message(addsHashtags: Bool) -> String {
        var lines = [
            material.isFinished
                ? L10n.format("『%@』を終えました", material.name)
                : L10n.format("『%@』を勉強中", material.name)
        ]
        lines.append(L10n.format("%@ · %d日 · %d回", WeeklyVlogMaker.durationText(totals.seconds), totals.days, totals.count))
        if addsHashtags {
            lines.append(L10n.string("#勉強垢 #勉強記録 #StudyReel"))
        }
        return lines.joined(separator: "\n")
    }
}

struct MaterialShareCard: View {
    let summary: MaterialShareSummary

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

            HStack(alignment: .top, spacing: 16) {
                MaterialCover(material: summary.material, cornerRadius: 6)
                    .frame(width: 84, height: 114)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                VStack(alignment: .leading, spacing: 6) {
                    if summary.material.isFinished {
                        Text(L10n.string("やり終えた！"))
                            .font(ReelTheme.sans(11, weight: .semibold))
                            .foregroundColor(ReelTheme.accentDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(ReelTheme.accentSoft))
                    }
                    Text(summary.material.name)
                        .font(ReelTheme.serif(19))
                        .foregroundColor(ReelTheme.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(summary.material.subject)
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
            }

            Text(WeeklyVlogMaker.durationText(summary.totals.seconds))
                .font(ReelTheme.serif(38))
                .foregroundColor(ReelTheme.ink)
                .monospacedDigit()
                .padding(.top, 20)
            Text(L10n.format("%d日 · %d回", summary.totals.days, summary.totals.count))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.ink)
                .padding(.top, 2)

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
}

// MARK: - 教科

struct SubjectShareSummary {
    struct MaterialTime {
        let name: String
        let seconds: Int
    }

    let subject: String
    let range: SubjectShareRange
    let headline: String
    let rangeText: String
    let totals: StudyTotals
    let materials: [MaterialTime]
    let thumbnail: UIImage?

    init(
        subject: String,
        range: SubjectShareRange,
        sessions allSessions: [StudySession],
        materials allMaterials: [StudyMaterial],
        includesPhoto: Bool,
        calendar: Calendar = .current
    ) {
        self.subject = subject
        self.range = range
        var sessions = allSessions.filter { $0.subject == subject }
        if range == .thisMonth, let month = calendar.dateInterval(of: .month, for: Date()) {
            sessions = sessions.filter { month.contains($0.date) }
            headline = L10n.format("今月の%@", subject)
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            rangeText = formatter.string(from: month.start)
        } else {
            headline = L10n.format("これまでの%@", subject)
            rangeText = shareRangeText(from: sessions.map(\.date).min(), to: sessions.map(\.date).max())
        }
        totals = StudyTotals(sessions: sessions, calendar: calendar)

        var byMaterial: [UUID: Int] = [:]
        for session in sessions {
            guard let id = session.materialID else { continue }
            byMaterial[id, default: 0] += session.duration
        }
        materials = byMaterial
            .sorted { $0.value > $1.value }
            .compactMap { entry in
                allMaterials.first { $0.id == entry.key }.map { MaterialTime(name: $0.name, seconds: entry.value) }
            }
            .prefix(3)
            .map { $0 }
        thumbnail = includesPhoto ? longestThumbnail(sessions) : nil
    }

    func message(addsHashtags: Bool) -> String {
        var lines = [headline]
        lines.append(L10n.format("合計 %@ · %d日", WeeklyVlogMaker.durationText(totals.seconds), totals.days))
        if !materials.isEmpty {
            lines.append(materials.map { "\($0.name) \(WeeklyVlogMaker.durationText($0.seconds))" }.joined(separator: " / "))
        }
        if addsHashtags {
            lines.append(L10n.string("#勉強垢 #勉強記録 #StudyReel"))
        }
        return lines.joined(separator: "\n")
    }
}

struct SubjectShareCard: View {
    let summary: SubjectShareSummary

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
            Text(WeeklyVlogMaker.durationText(summary.totals.seconds))
                .font(ReelTheme.serif(38))
                .foregroundColor(ReelTheme.ink)
                .monospacedDigit()
                .padding(.top, 2)
            Text(L10n.format("%d日勉強しました", summary.totals.days))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.ink)
                .padding(.top, 2)

            if !summary.materials.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(summary.materials.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.name)
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(WeeklyVlogMaker.durationText(item.seconds))
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
}
