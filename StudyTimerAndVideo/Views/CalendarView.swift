import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.dismiss) var dismiss
    @Query private var sessions: [StudySession]
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    
    var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }
    
    var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        
        let days = calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0)
        )
        return days
    }
    
    var sessionsForSelectedDate: [StudySession] {
        guard let date = selectedDate else { return [] }
        return sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                if isLandscape {
                    HStack(spacing: 0) {
                        // Left: Calendar
                        VStack {
                            calendarHeader
                            daysOfWeekHeader
                            ScrollView {
                                calendarGrid
                            }
                        }
                        .frame(width: geometry.size.width * 0.5)
                        
                        Divider()
                        
                        // Right: Details
                        VStack {
                            selectedDateHeader
                            if let _ = selectedDate {
                                sessionList
                            } else {
                                Spacer()
                                Text("日付を選択してください")
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                        .frame(width: geometry.size.width * 0.5)
                    }
                } else {
                    // Portrait
                    VStack {
                        calendarHeader
                        daysOfWeekHeader
                        calendarGrid
                        Divider()
                        selectedDateHeader
                        if let _ = selectedDate {
                            sessionList
                        } else {
                            Spacer()
                            Text("日付を選択してください")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("カレンダー")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Subviews
    
    var calendarHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthFormatter.string(from: currentMonth))
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }
    
    var daysOfWeekHeader: some View {
        HStack {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .frame(maxWidth: .infinity)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            // Padding for start of month
            if let first = daysInMonth.first {
                let weekday = calendar.component(.weekday, from: first)
                ForEach(0..<(weekday - 1), id: \.self) { _ in
                    Text("")
                }
            }
            
            ForEach(daysInMonth, id: \.self) { date in
                VStack {
                    Text("\(calendar.component(.day, from: date))")
                        .foregroundColor(calendar.isDate(date, inSameDayAs: Date()) ? .blue : .primary)
                        .fontWeight(calendar.isDate(date, inSameDayAs: Date()) ? .bold : .regular)
                    
                    if hasSession(on: date) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(8)
                .background(isSelected(date) ? Color.gray.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding()
    }
    
    var selectedDateHeader: some View {
        Group {
            if let date = selectedDate {
                Text(dateFormatter.string(from: date))
                    .font(.headline)
                    .padding(.top)
            }
        }
    }
    
    var sessionList: some View {
        Group {
            if sessionsForSelectedDate.isEmpty {
                Text("学習記録はありません")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            } else {
                List(sessionsForSelectedDate) { session in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.subject)
                                .font(.headline)
                            if let tags = session.tags, !tags.isEmpty {
                                HStack {
                                    ForEach(tags) { tag in
                                        Text(tag.name)
                                            .font(.caption2)
                                            .foregroundColor(tag.color)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Text(formatTime(session.duration))
                    }
                }
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func hasSession(on date: Date) -> Bool {
        sessions.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func isSelected(_ date: Date) -> Bool {
        guard let selected = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selected)
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return String(format: "%d時間%d分", h, m)
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
