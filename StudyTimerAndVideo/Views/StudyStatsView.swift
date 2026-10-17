import SwiftUI
import SwiftData
import Charts

// 07 統計（シンプル版）。週・月・年の合計と、よく勉強する時間帯だけを見せる
struct StudyStatsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager

    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager

    @State private var period: StatsPeriod = .month
    @State private var anchor = Date()
    @State private var showManualAdd = false
    @State private var showPaywall = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker(L10n.string("期間"), selection: $period) {
                        ForEach(StatsPeriod.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: period) { anchor = Date() }

                    periodNavigator

                    VStack(spacing: 6) {
                        Text(compactDuration(totalSeconds))
                            .font(ReelTheme.serif(40))
                            .foregroundColor(ReelTheme.ink)
                            .monospacedDigit()
                        Text(summaryLine)
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    barChart

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.string("よく勉強する時間帯"))
                            .font(ReelTheme.sans(13))
                            .foregroundColor(ReelTheme.ink)
                        hourStrip
                    }

                    subjectSection
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(L10n.string("統計"))
                        .font(ReelTheme.serif(24))
                        .foregroundColor(ReelTheme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showManualAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(L10n.string("手動追加"))
                        Button(L10n.string("閉じる")) { dismiss() }
                    }
                    .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Parts

    private var periodNavigator: some View {
        HStack {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(periodTitle)
                .font(ReelTheme.sans(15))
                .foregroundColor(ReelTheme.ink)
            Spacer()
            Button {
                move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentPeriod)
            .opacity(isCurrentPeriod ? 0.3 : 1)
        }
        .font(.system(size: 15, weight: .light))
        .foregroundColor(ReelTheme.secondary)
    }

    private var barChart: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("", bucket.label),
                y: .value("", Double(bucket.seconds) / 3600),
                width: .ratio(0.35)
            )
            .foregroundStyle(ReelTheme.accent)
            .cornerRadius(2)
        }
        .chartXAxis {
            AxisMarks(values: axisLabels) { _ in
                AxisValueLabel()
                    .font(ReelTheme.sans(10))
                    .foregroundStyle(ReelTheme.secondary)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 150)
    }

    private var hourStrip: some View {
        let totals = hourTotals
        let peak = max(totals.max() ?? 0, 1)
        return VStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(ReelTheme.accent.opacity(0.12 + 0.88 * Double(totals[hour]) / Double(peak)))
                        .frame(height: 18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text("\(hour)")
                    if hour != 24 { Spacer() }
                }
            }
            .font(ReelTheme.sans(10))
            .foregroundColor(ReelTheme.secondary)
        }
    }

    // 教科ごとの内訳は Pro
    @ViewBuilder
    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("教科別の内訳"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
                if !storeKit.isProUnlocked {
                    Text("Pro")
                        .font(ReelTheme.sans(11, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }

            if storeKit.isProUnlocked {
                let totals = subjectTotals
                if totals.isEmpty {
                    Text(L10n.string("まだ記録がありません"))
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(totals, id: \.subject) { item in
                            HStack(spacing: 10) {
                                Text(item.subject)
                                    .font(ReelTheme.sans(13))
                                    .foregroundColor(ReelTheme.ink)
                                    .frame(width: 84, alignment: .leading)
                                    .lineLimit(1)
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(ReelTheme.accent)
                                        .frame(width: max(4, geometry.size.width * CGFloat(item.seconds) / CGFloat(max(totalSeconds, 1))))
                                }
                                .frame(height: 6)
                                Text(compactDuration(item.seconds))
                                    .font(ReelTheme.sans(12))
                                    .foregroundColor(ReelTheme.secondary)
                                    .monospacedDigit()
                                    .frame(width: 64, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "lock")
                        Text(L10n.string("どの教科にどれだけ時間を使ったかを見られます"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data

    private struct Bucket: Identifiable {
        let id: Int
        let label: String
        let seconds: Int
    }

    private var interval: DateInterval {
        calendar.dateInterval(of: period.component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }

    private var periodSessions: [StudySession] {
        let range = interval
        return sessions.filter { range.contains($0.date) }
    }

    private var totalSeconds: Int {
        periodSessions.map(\.duration).reduce(0, +)
    }

    private var buckets: [Bucket] {
        let range = interval
        let items = periodSessions
        switch period {
        case .week, .month:
            var result: [Bucket] = []
            var day = range.start
            var index = 0
            while day < range.end {
                let total = items.filter { calendar.isDate($0.date, inSameDayAs: day) }.map(\.duration).reduce(0, +)
                result.append(Bucket(id: index, label: dayLabel(day), seconds: total))
                index += 1
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? range.end
            }
            return result
        case .year:
            return (1...12).map { month in
                let total = items.filter { calendar.component(.month, from: $0.date) == month }.map(\.duration).reduce(0, +)
                return Bucket(id: month, label: "\(month)", seconds: total)
            }
        }
    }

    private var axisLabels: [String] {
        switch period {
        case .week: return buckets.map(\.label)
        case .month: return ["1", "7", "14", "21", "28"]
        case .year: return ["1", "4", "7", "10", "12"]
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if period == .week {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            return formatter.string(from: date)
        }
        return "\(calendar.component(.day, from: date))"
    }

    // 勉強していた時間を、またがる時間帯ごとに振り分ける
    private var hourTotals: [Int] {
        var totals = Array(repeating: 0, count: 24)
        for session in periodSessions {
            var cursor = session.date
            var remaining = session.duration
            while remaining > 0 {
                let hour = calendar.component(.hour, from: cursor)
                let nextHour = calendar.dateInterval(of: .hour, for: cursor)?.end ?? cursor.addingTimeInterval(3600)
                let chunk = min(remaining, max(1, Int(nextHour.timeIntervalSince(cursor))))
                totals[hour] += chunk
                remaining -= chunk
                cursor = nextHour
            }
        }
        return totals
    }

    private var subjectTotals: [(subject: String, seconds: Int)] {
        Dictionary(grouping: periodSessions, by: \.subject)
            .map { ($0.key, $0.value.map(\.duration).reduce(0, +)) }
            .sorted { $0.1 > $1.1 }
    }

    private var studiedDays: Int {
        Set(periodSessions.map { calendar.startOfDay(for: $0.date) }).count
    }

    private var summaryLine: String {
        guard studiedDays > 0 else { return L10n.string("まだ記録がありません") }
        return L10n.format("%d日勉強 · 1日平均 %@", studiedDays, compactDuration(totalSeconds / studiedDays))
    }

    private var periodTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        switch period {
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            let end = interval.end.addingTimeInterval(-1)
            return "\(formatter.string(from: interval.start)) – \(formatter.string(from: end))"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: anchor)
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: anchor)
        }
    }

    private var isCurrentPeriod: Bool {
        interval.contains(Date())
    }

    private func move(by value: Int) {
        if let next = calendar.date(byAdding: period.component, value: value, to: anchor) {
            anchor = next
        }
    }

    private func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }
}

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return L10n.string("週")
        case .month: return L10n.string("月")
        case .year: return L10n.string("年")
        }
    }

    var component: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}
