import SwiftUI
import SwiftData

struct StudyStatsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                AppPalette.dashboardGradient(for: colorScheme)
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                        Button(action: { showTrend = true }) {
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

    var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            metricCard(title: L10n.string("Today"), value: formatHoursAndMinutes(todayTotalSeconds))
            metricCard(title: L10n.string("This Week"), value: formatHoursAndMinutes(thisWeekTotalSeconds))
            metricCard(title: L10n.string("Streak"), value: L10n.format("%d日", currentStreak))
            metricCard(title: L10n.string("Top Subject"), value: topSubject ?? L10n.string("No Data"))
        }
    }

    func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
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

            patternRow(title: L10n.string("よく始める時間"), value: patternMostCommonStartHourText)
            patternRow(title: L10n.string("平均継続時間"), value: formatHoursAndMinutes(patternAverageDurationSeconds))
            if !storeKit.isProUnlocked {
                proLockedCard
            } else if let selectedPatternSubject {
                patternRow(
                    title: L10n.string("先週比"),
                    value: StudyInsights.weeklyComparisonText(for: filteredSessions, subject: selectedPatternSubject)
                )
                patternRow(
                    title: L10n.string("集中しやすい時間"),
                    value: StudyInsights.strongestHourText(for: patternSessions)
                )
            } else if !patternSubjects.isEmpty {
                Text(L10n.string("教科を選ぶと、先週比と集中しやすい時間も表示されます。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
        )
    }

    var proLockedCard: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Text(L10n.string("教科別の先週比と集中しやすい時間帯は Pro で見られます。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func patternRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    func subjectChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? AppPalette.skyDeep : Color.gray.opacity(0.12))
                .foregroundColor(isSelected ? .white : .primary)
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
        )
    }

    func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? AppPalette.skyDeep : Color.gray.opacity(0.12))
                .foregroundColor(isSelected ? .white : .primary)
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
        )
    }

    func historyRow(for session: StudySession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.subject)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(formatHoursAndMinutes(session.duration))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
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
        .background(AppPalette.secondaryCardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(session)
            } label: {
                Text(L10n.string("削除"))
            }
        }
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

    private var topSubject: String? {
        subjectTotals.first?.key
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

    private var patternMostCommonStartHourText: String {
        StudyInsights.mostCommonStartHourText(for: patternSessions)
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
