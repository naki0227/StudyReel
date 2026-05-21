import SwiftUI
import Charts
import SwiftData

// MARK: - Trend Chart View
struct StudyStatsTrendView: View {
    let sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPeriod: Calendar.Component = .day
    @State private var chartData: [StackedItem] = []

    var body: some View {
        NavigationView {
            ZStack {
                AppPalette.dashboardGradient(for: colorScheme)
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        introCard
                        periodPickerCard
                        chartCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.string("勉強時間の推移"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("閉じる")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            updateData()
        }
        .onChange(of: selectedPeriod) {
            updateData()
        }
        .onChange(of: sessions.count) {
            updateData()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Study Flow"))
                .font(.headline)
                .foregroundColor(AppPalette.accentText(for: colorScheme))

            Text(L10n.string("どの教科が、いつ積み上がっているか"))
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

            Text(L10n.string("期間を切り替えると、日・週・月・年の流れを見比べられます。"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
        )
    }

    private var periodPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("期間"))
                .font(.headline)

            Picker(L10n.string("期間"), selection: $selectedPeriod) {
                Text(L10n.string("日")).tag(Calendar.Component.day)
                Text(L10n.string("週")).tag(Calendar.Component.weekOfYear)
                Text(L10n.string("月")).tag(Calendar.Component.month)
                Text(L10n.string("年")).tag(Calendar.Component.year)
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
        )
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("教科ごとの積み上げ"))
                .font(.headline)

            if chartData.isEmpty {
                Text(L10n.string("まだグラフにできる記録がありません"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
            } else {
                Chart {
                    ForEach(chartData) { item in
                        BarMark(
                            x: .value(L10n.string("日付"), item.dateStr),
                            y: .value(L10n.string("時間"), Double(item.duration) / 60.0)
                        )
                        .foregroundStyle(by: .value(L10n.string("教科"), item.subject))
                    }
                }
                .chartYAxisLabel(L10n.string("時間 (分)"))
                .chartLegend(position: .bottom, spacing: 8)
                .frame(height: 320)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppPalette.cardFill(for: colorScheme))
        )
    }

    struct StackedItem: Identifiable {
        let id = UUID()
        let dateStr: String
        let subject: String
        let duration: Int
    }

    private func updateData() {
        let sessions = self.sessions
        let subjects = subjectManager.subjects
        let period = selectedPeriod

        DispatchQueue.global(qos: .userInitiated).async {
            let items = Self.calculateStackedTimeSeries(sessions: sessions, subjects: subjects, period: period)
            DispatchQueue.main.async {
                chartData = items
            }
        }
    }

    private static func calculateStackedTimeSeries(sessions: [StudySession], subjects: [String], period: Calendar.Component) -> [StackedItem] {
        let calendar = Calendar.current
        let now = Date()
        let range = 0..<7
        var items: [StackedItem] = []

        for i in range.reversed() {
            guard let date = calendar.date(byAdding: period, value: -i, to: now) else { continue }

            let sessionsInPeriod = sessions.filter { session in
                switch period {
                case .day:
                    return calendar.isDate(session.date, inSameDayAs: date)
                case .weekOfYear:
                    return calendar.isDate(session.date, equalTo: date, toGranularity: .weekOfYear)
                case .month:
                    return calendar.isDate(session.date, equalTo: date, toGranularity: .month)
                case .year:
                    return calendar.isDate(session.date, equalTo: date, toGranularity: .year)
                default:
                    return false
                }
            }

            for subject in subjects {
                let total = sessionsInPeriod
                    .filter { $0.subject == subject }
                    .map(\.duration)
                    .reduce(0, +)

                if total > 0 {
                    items.append(
                        StackedItem(
                            dateStr: L10n.chartDateLabel(for: period, date: date),
                            subject: subject,
                            duration: total
                        )
                    )
                }
            }
        }

        return items
    }
}
