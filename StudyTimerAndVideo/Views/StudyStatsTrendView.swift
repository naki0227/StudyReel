import SwiftUI
import Charts
import SwiftData

//MARK: - 期間ごとの積み上げ棒グラフ
struct StudyStatsTrendView: View {
    // Pass sessions directly instead of logManager
    let sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPeriod: Calendar.Component = .day
    @State private var chartData: [StackedItem] = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.05).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .padding(12)
                                .background(Color.blue.opacity(0.6))
                                .clipShape(Circle())
                                .foregroundColor(.white)
                        }
                        
                        Text("勉強時間の推移")
                            .font(.title2)
                            .padding(12)
                            .background(Color.blue.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Picker("期間", selection: $selectedPeriod) {
                        Text("日").tag(Calendar.Component.day)
                        Text("週").tag(Calendar.Component.weekOfYear)
                        Text("月").tag(Calendar.Component.month)
                        Text("年").tag(Calendar.Component.year)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 20)
                    .onChange(of: selectedPeriod) { _ in
                        updateData()
                    }
                    
                    Chart {
                        ForEach(chartData) { item in
                            BarMark(
                                x: .value("日付", item.dateStr),
                                y: .value("時間", Double(item.duration) / 60.0)
                            )
                            .foregroundStyle(by: .value("教科", item.subject))
                        }
                    }
                    .chartYAxisLabel("時間 (分)")
                    .frame(height: 300)
                    .padding(.horizontal, 30) // Add more horizontal padding
                    .padding(.bottom, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear {
            updateData()
        }
        .onChange(of: sessions.count) { _ in
            updateData()
        }
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
        
        // Run calculation on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let items = StudyStatsTrendView.calculateStackedTimeSeries(sessions: sessions, subjects: subjects, period: period)
            DispatchQueue.main.async {
                self.chartData = items
            }
        }
    }
    
    private static func calculateStackedTimeSeries(sessions: [StudySession], subjects: [String], period: Calendar.Component) -> [StackedItem] {
        let calendar = Calendar.current
        let now = Date()
        var items: [StackedItem] = []
        
        let range = 0..<7
        
        // Reuse DateFormatter
        let formatter = DateFormatter()
        switch period {
        case .day: formatter.dateFormat = "MM/dd"
        case .weekOfYear: formatter.dateFormat = "MM/dd週"
        case .month: formatter.dateFormat = "MM月"
        case .year: formatter.dateFormat = "yyyy年"
        default: formatter.dateFormat = "MM/dd"
        }
        
        for i in range.reversed() {
            guard let date = calendar.date(byAdding: period, value: -i, to: now) else { continue }
            
            // Filter sessions for the period
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
                default: return false
                }
            }
            
            // Aggregate by subject
            for subject in subjects {
                let total = sessionsInPeriod.filter { $0.subject == subject }
                    .map { $0.duration }
                    .reduce(0, +)
                
                if total > 0 {
                    let dateStr = formatter.string(from: date)
                    items.append(StackedItem(dateStr: dateStr, subject: subject, duration: total))
                }
            }
        }
        return items
    }
}
