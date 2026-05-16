import SwiftUI
import SwiftData

struct StudyStatsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKit: StoreKitManager

    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @Query private var tags: [Tag]

    @ObservedObject var subjectManager: SubjectManager

    @State private var showTrend = false
    @State private var showManualAdd = false
    @State private var showSubjectManager = false
    @State private var showPaywall = false
    @State private var selectedTag: Tag?
    @State private var selectedPatternSubject: String?

    private let calendar = Calendar.current

    var filteredSessions: [StudySession] {
        if let tag = selectedTag {
            return sessions.filter { $0.tags?.contains(tag) ?? false }
        }
        return sessions
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.98, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 0.98),
                        Color(red: 0.85, green: 0.91, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        overviewGrid
                        pastYouPatternCard
                        filterCard
                        historyCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.string("学習統計"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("閉じる")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showManualAdd = true }) {
                            Image(systemName: "plus")
                        }
                        Button(action: { showSubjectManager = true }) {
                            Image(systemName: "book.closed")
                        }
                        Button(action: {
                            if storeKit.isProUnlocked {
                                showTrend = true
                            } else {
                                showPaywall = true
                            }
                        }) {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    }
                }
            }
            .sheet(isPresented: $showTrend) {
                StudyStatsTrendView(sessions: filteredSessions, subjectManager: subjectManager)
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showSubjectManager) {
                SubjectEditView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Past You Dashboard"))
                .font(.headline)
                .foregroundColor(Color.blue.opacity(0.9))

            Text(L10n.string("記録ではなく、勉強の流れを見る"))
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)

            Text(summaryLine)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { showSubjectManager = true }) {
                Label(L10n.string("教科を管理"), systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.10))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

    var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            metricCard(title: L10n.string("Today"), value: formatHoursAndMinutes(todayTotalSeconds), tone: Color.blue)
            metricCard(title: L10n.string("This Week"), value: formatHoursAndMinutes(thisWeekTotalSeconds), tone: Color.teal)
            metricCard(title: L10n.string("Streak"), value: L10n.format("%d日", currentStreak), tone: Color.orange)
            metricCard(title: L10n.string("Top Subject"), value: topSubject ?? L10n.string("No Data"), tone: Color.indigo)
        }
    }

    func metricCard(title: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(tone)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    var pastYouPatternCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Past You Patterns"))
                .font(.headline)

            if !patternSubjects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        subjectChip(title: L10n.string("All Subjects"), isSelected: selectedPatternSubject == nil) {
                            selectedPatternSubject = nil
                        }
                        ForEach(patternSubjects, id: \.self) { subject in
                            subjectChip(title: subject, isSelected: selectedPatternSubject == subject) {
                                selectedPatternSubject = subject
                            }
                        }
                    }
                }
            }

            patternRow(
                title: L10n.string("よく始める時間"),
                value: patternMostCommonStartHourText,
                detail: selectedPatternSubject == nil ? L10n.string("過去の自分が一番入りやすかった時間帯") : L10n.string("この教科で一番入りやすかった時間帯")
            )
            patternRow(
                title: L10n.string("平均継続時間"),
                value: formatHoursAndMinutes(patternAverageDurationSeconds),
                detail: selectedPatternSubject == nil ? L10n.string("無理なく続けられている基準") : L10n.string("この教科で無理なく続けられている基準")
            )
            patternRow(
                title: L10n.string("この時間帯の気配"),
                value: L10n.format("%d records", patternSessionsNearCurrentHour),
                detail: selectedPatternSubject == nil ? L10n.string("今と近い時間に始まった過去セッション") : L10n.string("この教科で今と近い時間に始まった過去セッション")
            )
            if !storeKit.isProUnlocked {
                proLockedCard
            } else if let selectedPatternSubject {
                patternRow(
                    title: L10n.string("先週比"),
                    value: StudyInsights.weeklyComparisonText(for: filteredSessions, subject: selectedPatternSubject),
                    detail: L10n.string("この教科が先週と比べてどれだけ伸びたか")
                )
                patternRow(
                    title: L10n.string("強い時間帯"),
                    value: StudyInsights.strongestHourText(for: patternSessions),
                    detail: L10n.string("この教科で集中が始まりやすい時間帯")
                )
            }

            if !topSubjects.isEmpty && selectedPatternSubject == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("よく積み上がっている教科"))
                        .font(.subheadline.weight(.semibold))
                    FlowSubjects(subjects: topSubjects)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    var proLockedCard: some View {
        Button(action: { showPaywall = true }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("StudyReel Pro"))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.blue)
                Text(L10n.string("教科別の先週比や強い時間帯は Pro で見られます。"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(L10n.string("Proを始める"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func patternRow(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)
            }
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    func subjectChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? Color.indigo.opacity(0.14) : Color.gray.opacity(0.10))
                .foregroundColor(isSelected ? .indigo : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("Filter"))
                    .font(.headline)
                Spacer()
                if selectedTag != nil {
                    Button(L10n.string("フィルタ解除")) {
                        selectedTag = nil
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: L10n.string("すべて"), isSelected: selectedTag == nil) {
                        selectedTag = nil
                    }
                    ForEach(tags) { tag in
                        filterChip(title: tag.name, isSelected: selectedTag == tag) {
                            selectedTag = tag
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? Color.blue.opacity(0.16) : Color.gray.opacity(0.10))
                .foregroundColor(isSelected ? .blue : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.string("学習履歴"))
                    .font(.headline)
                Spacer()
                Text(L10n.format("%d sessions", filteredSessions.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if filteredSessions.isEmpty {
                Text(L10n.string("まだ記録がありません"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredSessions.prefix(20)) { session in
                        historyRow(for: session)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    func historyRow(for session: StudySession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(String(session.subject.prefix(1)))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.subject)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(formatClockTime(session.duration))
                        .font(.subheadline.weight(.bold))
                }

                Text(formatDate(session.date))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let tags = session.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags) { tag in
                                Text(tag.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tag.color.opacity(0.14))
                                    .foregroundColor(tag.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(session)
            } label: {
                Text(L10n.string("削除"))
            }
        }
    }

    private var summaryLine: String {
        if filteredSessions.isEmpty {
            return L10n.string("最初の1セッションを記録すると、過去の自分の傾向がここに育っていきます。")
        }
        return L10n.format("今日は %@、今週は %@。過去の自分の流れが少しずつ見えてきています。", formatHoursAndMinutes(todayTotalSeconds), formatHoursAndMinutes(thisWeekTotalSeconds))
    }

    private var todayTotalSeconds: Int {
        filteredSessions
            .filter { calendar.isDateInToday($0.date) }
            .map(\.duration)
            .reduce(0, +)
    }

    private var thisWeekTotalSeconds: Int {
        filteredSessions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
            .map(\.duration)
            .reduce(0, +)
    }

    private var averageDurationSeconds: Int {
        StudyInsights.averageDurationSeconds(for: filteredSessions)
    }

    private var patternSessions: [StudySession] {
        if let selectedPatternSubject {
            return filteredSessions.filter { $0.subject == selectedPatternSubject }
        }
        return filteredSessions
    }

    private var patternSubjects: [String] {
        Array(subjectTotals.prefix(6).map(\.key))
    }

    private var patternAverageDurationSeconds: Int {
        StudyInsights.averageDurationSeconds(for: patternSessions)
    }

    private var patternSessionsNearCurrentHour: Int {
        StudyInsights.sessionsNearCurrentHour(patternSessions)
    }

    private var sessionsNearCurrentHour: Int {
        StudyInsights.sessionsNearCurrentHour(filteredSessions)
    }

    private var topSubject: String? {
        subjectTotals.first?.key
    }

    private var topSubjects: [String] {
        Array(subjectTotals.prefix(4).map(\.key))
    }

    private var subjectTotals: [(key: String, value: Int)] {
        Dictionary(grouping: filteredSessions, by: \.subject)
            .map { ($0.key, $0.value.map(\.duration).reduce(0, +)) }
            .sorted { $0.value > $1.value }
    }

    private var currentStreak: Int {
        let days = Set(filteredSessions.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private var mostCommonStartHourText: String {
        StudyInsights.mostCommonStartHourText(for: filteredSessions)
    }

    private var patternMostCommonStartHourText: String {
        StudyInsights.mostCommonStartHourText(for: patternSessions)
    }

    private func formatClockTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func formatHoursAndMinutes(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return L10n.format("%d時間%d分", hours, minutes)
        }
        return L10n.format("%d分", minutes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: date)
    }
}

private struct FlowSubjects: View {
    let subjects: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
            ForEach(subjects, id: \.self) { subject in
                Text(subject)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.10))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
        }
    }
}
