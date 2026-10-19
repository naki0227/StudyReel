import SwiftUI
import SwiftData

// カレンダー。勉強した日ほど濃い色で、日付をタップするとその日の記録が並ぶ
struct CalendarView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager

    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = .autoupdatingCurrent
        return cal
    }

    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        return calendar.generateDates(inside: monthInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }

    private var leadingBlanks: Int {
        guard let first = daysInMonth.first else { return 0 }
        return (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var sessionsForSelectedDate: [StudySession] {
        sessions.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var monthlyPeak: Int {
        max(daysInMonth.map(totalSeconds(on:)).max() ?? 0, 1)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                ScrollView {
                    Group {
                        if isLandscape {
                            HStack(alignment: .top, spacing: 24) {
                                monthCard
                                dayList
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 20) {
                                monthCard
                                dayList
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(L10n.string("カレンダー"))
                        .font(ReelTheme.serif(24))
                        .foregroundColor(ReelTheme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
        }
    }

    // MARK: - Subviews

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthTitle(currentMonth))
                    .font(ReelTheme.sans(15))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
                Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
            }
            .font(.system(size: 15, weight: .light))
            .foregroundColor(ReelTheme.secondary)

            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(daysInMonth, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private func dayCell(_ date: Date) -> some View {
        let total = totalSeconds(on: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let intensity = total > 0 ? 0.25 + 0.75 * Double(total) / Double(monthlyPeak) : 0

        return Button {
            selectedDate = date
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(ReelTheme.sans(14, weight: isToday ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : ReelTheme.ink)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isSelected ? ReelTheme.accentDeep : ReelTheme.accent.opacity(intensity))
                )
                .overlay(
                    Circle().stroke(isToday && !isSelected ? ReelTheme.accentDeep : Color.clear, lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.plain)
    }

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayTitle(selectedDate))
                    .font(ReelTheme.serif(18))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
                let total = totalSeconds(on: selectedDate)
                if total > 0 {
                    Text(compactDuration(total))
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                }
            }

            if sessionsForSelectedDate.isEmpty {
                Text(L10n.string("学習記録はありません"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessionsForSelectedDate) { session in
                    NavigationLink {
                        SessionDetailView(session: session, subjectManager: subjectManager)
                    } label: {
                        HStack(spacing: 12) {
                            SessionThumbnail(fileName: session.thumbnailFileName, subject: session.subject)
                                .frame(width: 72, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.displayTitle)
                                    .font(ReelTheme.sans(14))
                                    .foregroundColor(ReelTheme.ink)
                                    .lineLimit(1)
                                Text(timeRange(session))
                                    .font(ReelTheme.sans(11))
                                    .foregroundColor(ReelTheme.secondary)
                            }
                            Spacer()
                            Text(compactDuration(session.duration))
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func totalSeconds(on date: Date) -> Int {
        sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }.map(\.duration).reduce(0, +)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }

    private func timeRange(_ session: StudySession) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        let end = session.date.addingTimeInterval(TimeInterval(session.duration))
        return "\(formatter.string(from: session.date)) – \(formatter.string(from: end))"
    }

    private func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }
}

extension Calendar {
    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)
        
        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }
        
        return dates
    }
}
