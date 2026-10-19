import SwiftData
import SwiftUI

// 目標と過去問の共有カード。ストーリーズに合う縦長（9:16）の画像にして送る
//  - 宣言：目標を決めたとき
//  - 途中経過：いつでも
//  - 点数アップ：同じ問題を2回以上解いたとき
//  - 達成：達成を記録したとき
struct GoalShareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Query(sort: \StudySession.date) private var sessions: [StudySession]
    @Query(sort: \PastPaperResult.date) private var papers: [PastPaperResult]
    @AppStorage(StudyShareView.hashtagKey) private var addsHashtags = true
    @AppStorage(StudyShareView.photoKey) private var includesPhoto = true

    let goal: StudyGoal?
    @State private var kind: GoalCardKind
    @State private var paperName: String?
    @State private var image: UIImage?

    init(goal: StudyGoal?, initialKind: GoalCardKind = .declaration, initialPaper: String? = nil) {
        self.goal = goal
        _kind = State(initialValue: initialKind)
        _paperName = State(initialValue: initialPaper)
    }

    private var availableKinds: [GoalCardKind] {
        GoalCardKind.allCases.filter { kind in
            switch kind {
            case .declaration, .progress: return goal != nil
            case .scoreUp: return !series.isEmpty
            case .achieved: return goal?.isAchieved == true
            }
        }
    }

    // 点数のある回が2回以上ある問題
    private var series: [PaperSeries] {
        PaperSeries.group(papers).filter { $0.gain != nil }
    }

    private var selectedSeries: PaperSeries? {
        series.first { $0.name == paperName } ?? series.first
    }

    private var content: GoalCardContent {
        GoalCardContent(
            goal: goal,
            progress: goal.map { GoalProgress(goal: $0, sessions: sessions, papers: papers) },
            series: selectedSeries,
            photo: includesPhoto ? sessions.last.flatMap { MediaStore.thumbnail(named: $0.thumbnailFileName) } : nil
        )
    }

    private var renderKey: String {
        [kind.rawValue, selectedSeries?.name ?? "", String(includesPhoto), String(sessions.count), String(papers.count),
         goal.map { "\($0.title)\($0.deadline.timeIntervalSince1970)\($0.note)\($0.achievedScore ?? -1)" } ?? ""]
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if availableKinds.count > 1 {
                        Picker("", selection: $kind) {
                            ForEach(availableKinds) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if kind == .scoreUp, series.count > 1 {
                        Menu {
                            ForEach(series) { item in
                                Button(item.name) { paperName = item.name }
                            }
                        } label: {
                            HStack {
                                Text(selectedSeries?.name ?? "")
                                Image(systemName: "chevron.down").font(.system(size: 11))
                            }
                            .font(ReelTheme.sans(13))
                            .foregroundColor(ReelTheme.accentDeep)
                        }
                    }

                    GoalShareCard(kind: kind, content: content)
                        .frame(width: 300, height: 533)
                        .scaleEffect(1)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: ReelTheme.ink.opacity(0.12), radius: 18, y: 8)
                        .accessibilityIdentifier("goal.share.card")

                    Toggle(L10n.string("最近の記録の写真を入れる"), isOn: $includesPhoto)
                        .font(ReelTheme.sans(13))
                        .tint(ReelTheme.accent)
                        .padding(.horizontal, 8)

                    if let image {
                        let picture = Image(uiImage: image)
                        ShareLink(item: picture, message: Text(message), preview: SharePreview(kind.title, image: picture)) {
                            Label(L10n.string("画像で共有"), systemImage: "square.and.arrow.up")
                                .font(ReelTheme.sans(15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Capsule().fill(ReelTheme.accentDeep))
                        }
                    }
                    ShareLink(item: message) {
                        Label(L10n.string("文章だけ"), systemImage: "text.bubble")
                            .font(ReelTheme.sans(14, weight: .medium))
                            .foregroundColor(ReelTheme.accentDeep)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Capsule().fill(ReelTheme.accentSoft))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("カードで共有"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .onAppear {
                if !availableKinds.contains(kind), let first = availableKinds.first { kind = first }
            }
            .task(id: renderKey) { render() }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var message: String {
        var lines: [String] = []
        let c = content
        switch kind {
        case .declaration:
            if let goal = c.goal {
                lines.append(L10n.format("%@ を目指して勉強します！", goal.title))
                lines.append(L10n.format("%@（%@まで）", goal.dDayText(), shortDate(goal.deadline)))
                if !goal.note.isEmpty { lines.append(goal.note) }
            }
        case .progress:
            if let goal = c.goal, let progress = c.progress {
                lines.append(L10n.format("%@ まで %@", goal.title, goal.dDayText()))
                lines.append(L10n.format("ここまで %@時間・%d日連続", hoursText(progress.studiedHours), progress.streakDays))
            }
        case .scoreUp:
            if let series = c.series, let gain = series.gain, let last = series.latest?.score {
                lines.append(L10n.format("%@、%d回目で %d点（%@）", series.name, series.results.count, last, signed(gain)))
            }
        case .achieved:
            if let goal = c.goal {
                lines.append(L10n.format("%@、達成しました！", goal.title))
                if let score = goal.achievedScore { lines.append(L10n.format("本番 %d点", score)) }
            }
        }
        if addsHashtags {
            lines.append("#StudyReel #" + L10n.string("勉強垢") + " #" + L10n.string("勉強記録"))
        }
        return lines.joined(separator: "\n")
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: GoalShareCard(kind: kind, content: content).frame(width: 360, height: 640))
        renderer.scale = 3
        image = renderer.uiImage
    }
}

enum GoalCardKind: String, CaseIterable, Identifiable {
    case declaration
    case progress
    case scoreUp
    case achieved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .declaration: return L10n.string("宣言")
        case .progress: return L10n.string("途中経過")
        case .scoreUp: return L10n.string("点数アップ")
        case .achieved: return L10n.string("達成")
        }
    }
}

struct GoalCardContent {
    let goal: StudyGoal?
    let progress: GoalProgress?
    let series: PaperSeries?
    let photo: UIImage?
}

// 360×640pt で描いて、画面ではそのまま縮める
struct GoalShareCard: View {
    let kind: GoalCardKind
    let content: GoalCardContent
    var theme: GoalTheme = .sky

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 360
            card
                .frame(width: 360, height: 640)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(360 / 640, contentMode: .fit)
    }

    @ViewBuilder
    private var card: some View {
        ZStack(alignment: .topLeading) {
            if kind == .achieved {
                LinearGradient(colors: [Color(red: 0.863, green: 0.918, blue: 0.965), Color(red: 0.686, green: 0.796, blue: 0.902)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                GridPaperBackground(color: theme.paper)
            }
            VStack(alignment: .leading, spacing: 0) {
                switch kind {
                case .declaration: declaration
                case .progress: progressCard
                case .scoreUp: scoreUp
                case .achieved: achieved
                }
                Spacer(minLength: 0)
                HStack {
                    GoalScript(text: footerScript, size: 12, color: kind == .achieved ? Color(red: 0.31, green: 0.44, blue: 0.56) : ReelTheme.secondary)
                    Spacer()
                    Text("StudyReel")
                        .font(ReelTheme.serif(14))
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 360, height: 640)
        .clipped()
    }

    private var footerScript: String {
        switch kind {
        case .declaration: return "study with me ♡"
        case .progress: return "keep going ✦"
        case .scoreUp: return content.goal.map { "\($0.title) · \($0.dDayText())" } ?? "keep going ✦"
        case .achieved: return "thank you, me ♡"
        }
    }

    private func header(_ script: String, _ trailing: String, color: Color = ReelTheme.secondary) -> some View {
        HStack {
            GoalScript(text: script, size: 17, color: color)
            Spacer()
            Text(trailing)
                .font(ReelTheme.sans(10, weight: .medium))
                .kerning(0.6)
                .foregroundColor(color)
        }
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    // MARK: 宣言

    @ViewBuilder
    private var declaration: some View {
        if let goal = content.goal {
            header("my goal ✦", dateText(goal.createdAt))
            DDayText(goal: goal, size: 108, theme: theme, now: goal.createdAt)
                .padding(.top, 26)
            Text(L10n.format("%@まで", goal.deadline.formatted(.dateTime.month().day().weekday(.abbreviated))))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
                .padding(.top, 12)
            TapedPaper(tape: GoalTheme.tapeBlue, tapeAngle: -4) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(goal.title)
                        .font(ReelTheme.serif(28))
                        .foregroundColor(ReelTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        if let hours = goal.targetHours { GoalPill(value: "\(hours)h", label: L10n.string("勉強する")) }
                        if let best = content.progress?.bestScore { GoalPill(value: "\(best)", label: L10n.string("いまの最高点")) }
                    }
                    if !goal.note.isEmpty {
                        Text(goal.note)
                            .font(ReelTheme.sans(13))
                            .lineSpacing(6)
                            .foregroundColor(ReelTheme.ink)
                            .lineLimit(4)
                    }
                }
            }
            .padding(.top, 24)
            HStack {
                Spacer()
                Polaroid(image: content.photo, caption: "day 1 ✎", badge: "", tape: GoalTheme.tapePink, angle: 3)
                    .frame(width: 168)
            }
            .padding(.top, 26)
        }
    }

    // MARK: 途中経過

    @ViewBuilder
    private var progressCard: some View {
        if let goal = content.goal, let progress = content.progress {
            header("my progress", "\(goal.title) · \(goal.dDayText())")
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(hoursText(progress.studiedHours))
                    .font(ReelTheme.serif(96))
                    .kerning(-3)
                    .foregroundColor(ReelTheme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    GoalScript(text: "hours", size: 20)
                    if let target = goal.targetHours {
                        Text(L10n.format("/ %d時間", target))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                    }
                }
            }
            .padding(.top, 20)
            GoalMeter(ratio: progress.hoursRatio ?? 0, height: 8, theme: theme)
                .padding(.top, 14)
            TapedPaper(tape: GoalTheme.tapeYellow, tapeAlignment: .topTrailing, tapeAngle: 5) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        GoalScript(text: "this week", size: 15)
                        Spacer()
                        Text(L10n.format("%d日", progress.lastSevenDays.filter { $0 }.count))
                            .font(ReelTheme.serif(22))
                            .foregroundColor(ReelTheme.ink)
                    }
                    HStack(spacing: 6) {
                        ForEach(Array(progress.lastSevenDays.enumerated()), id: \.offset) { index, studied in
                            Circle()
                                .fill(index == 6 && studied ? theme.deep : studied ? theme.accent : theme.soft)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Text(weekdayLetter(daysAgo: 6 - index))
                                        .font(ReelTheme.sans(9, weight: .medium))
                                        .foregroundColor(studied ? .white : ReelTheme.secondary)
                                )
                        }
                    }
                    if let target = goal.targetScore {
                        Rectangle().fill(ReelTheme.line).frame(height: 1)
                        HStack {
                            GoalScript(text: "best score", size: 15)
                            Spacer()
                            Text(progress.bestScore.map(String.init) ?? "—")
                                .font(ReelTheme.serif(22))
                                .foregroundColor(ReelTheme.ink)
                            Text("/ \(target)")
                                .font(ReelTheme.sans(11))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        GoalMeter(ratio: progress.scoreRatio ?? 0, height: 6, theme: theme)
                    }
                }
            }
            .padding(.top, 22)
            HStack(spacing: 6) {
                GoalPill(value: L10n.format("%d日", progress.streakDays), label: L10n.string("連続"))
                GoalPill(value: L10n.format("%d回解いた", progress.paperCount), label: L10n.string("過去問"))
            }
            .padding(.top, 16)
            if let photo = content.photo {
                HStack {
                    Spacer()
                    Polaroid(image: photo, caption: "today ✦", tape: GoalTheme.tapeYellow, angle: -3)
                        .frame(width: 130)
                }
                .padding(.top, 14)
            }
        }
    }

    private func weekdayLetter(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return String(date.formatted(.dateTime.weekday(.narrow)))
    }

    // MARK: 点数アップ

    @ViewBuilder
    private var scoreUp: some View {
        if let series = content.series, let gain = series.gain {
            header("score up ↗", series.latest.map { dateText($0.date) } ?? "")
            Text(series.name)
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.ink)
                .lineLimit(1)
                .padding(.top, 20)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(signed(gain))
                    .font(ReelTheme.serif(92))
                    .kerning(-3)
                    .foregroundColor(theme.deep)
                GoalScript(text: "pts", size: 17)
            }
            .padding(.top, 4)
            TapedPaper(tape: GoalTheme.tapeBlue, tapeAlignment: .top, tapeAngle: -2) {
                scoreBars(series)
            }
            .padding(.top, 22)
            let latestParts = series.latest?.parts.filter { $0.score != nil } ?? []
            HStack(spacing: 6) {
                ForEach(latestParts.prefix(2)) { part in
                    GoalPill(value: part.score.map(String.init) ?? "", label: part.name)
                }
                if let target = content.goal?.targetScore, let last = series.latest?.score, target > last,
                   content.goal?.maxScore == nil || content.goal?.maxScore == series.latest?.maxScore {
                    GoalPill(value: L10n.format("あと%d", target - last), label: L10n.string("目標まで"))
                }
            }
            .padding(.top, 16)
            if let memo = series.latest?.memo, !memo.isEmpty {
                TapedPaper(tape: GoalTheme.tapePink, tapeAlignment: .topTrailing, tapeAngle: 4, padding: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        GoalScript(text: "memo", size: 13)
                        Text(memo)
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.ink)
                            .lineLimit(2)
                    }
                }
                .rotationEffect(.degrees(-1.5))
                .padding(.top, 20)
            }
        }
    }

    private func scoreBars(_ series: PaperSeries) -> some View {
        let shown = Array(series.results.filter { $0.score != nil }.suffix(4))
        let scores = shown.compactMap(\.score)
        let low = Double(scores.min() ?? 0)
        let high = Double(scores.max() ?? 1)
        let offset = series.results.count - shown.count
        return HStack(alignment: .bottom, spacing: 14) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, result in
                let isLast = index == shown.count - 1
                let value = Double(result.score ?? 0)
                // いちばん低い回も見えるよう、下に 40% の底をつけて高さを割り振る
                let ratio = high > low ? 0.4 + 0.6 * (value - low) / (high - low) : 1
                VStack(spacing: 8) {
                    Text("\(result.score ?? 0)")
                        .font(ReelTheme.serif(isLast ? 26 : 20))
                        .foregroundColor(isLast ? theme.deep : ReelTheme.ink)
                    UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 14, style: .continuous)
                        .fill(isLast ? theme.accent : theme.soft)
                        .frame(height: 120 * ratio)
                    GoalScript(text: ordinal(offset + index + 1) + (isLast ? " ✦" : ""), size: 12)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 190, alignment: .bottom)
    }

    private func ordinal(_ number: Int) -> String {
        switch number {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(number)th"
        }
    }

    // MARK: 達成

    @ViewBuilder
    private var achieved: some View {
        if let goal = content.goal, let progress = content.progress {
            let blue = Color(red: 0.31, green: 0.44, blue: 0.56)
            header("goal achieved ✦", dateText(goal.achievedAt ?? Date()), color: theme.deep)
            Text(goal.title)
                .font(ReelTheme.serif(30))
                .foregroundColor(ReelTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, 22)
            if let score = goal.achievedScore {
                Text("\(score)")
                    .font(ReelTheme.serif(128))
                    .kerning(-5)
                    .foregroundColor(ReelTheme.ink)
                    .padding(.top, 2)
            } else {
                Text("D-day")
                    .font(ReelTheme.serif(96))
                    .foregroundColor(ReelTheme.ink)
            }
            Text(L10n.string("目標、達成しました"))
                .font(ReelTheme.sans(12))
                .foregroundColor(blue)
                .padding(.top, 6)
            HStack(alignment: .top) {
                Polaroid(image: content.photo, caption: "D-day ♡", badge: "\(hoursText(progress.studiedHours))h", tape: GoalTheme.tapeYellow, angle: -3)
                    .frame(width: 180)
                Spacer()
                VStack(spacing: 0) {
                    Text("\(progress.goal.dayNumber(at: goal.achievedAt ?? Date()))")
                        .font(ReelTheme.serif(24))
                        .foregroundColor(theme.deep)
                    GoalScript(text: "days ✦", size: 10)
                }
                .frame(width: 74, height: 74)
                .background(Circle().fill(Color.white).shadow(color: ReelTheme.ink.opacity(0.18), radius: 8, y: 4))
                .rotationEffect(.degrees(8))
                .padding(.top, 120)
            }
            .padding(.top, 20)
            HStack(spacing: 6) {
                GoalPill(value: "\(hoursText(progress.studiedHours))h", label: L10n.string("勉強"))
                GoalPill(value: L10n.format("%d日", progress.studyDays), label: L10n.string("勉強した日"))
            }
            .padding(.top, 18)
            if let first = progress.firstScore, let score = goal.achievedScore {
                GoalPill(value: "\(first)→\(score)", label: L10n.string("過去問から"))
                    .padding(.top, 6)
            }
        }
    }
}
