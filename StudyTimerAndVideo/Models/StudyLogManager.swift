import Foundation

//MARK: - ログ管理クラス
class StudyLogManager: ObservableObject {
    @Published var sessions: [LegacyStudySession] = [] {
        didSet { save() }
    }
    
    private let key = "study_sessions"
    
    init() {
        load()
    }
    
    func addSession(subject: String, duration: Int, date: Date = Date()) {
        let session = LegacyStudySession(subject: subject, duration: duration, date: date)
        sessions.insert(session, at: 0)
    }
    
    func totalTime(for subject: String) -> Int {
        sessions.filter { $0.subject == subject }
            .map { $0.duration }
            .reduce(0, +)
    }
    
    func totalTimeAll () -> Int {
        sessions.map { $0.duration }.reduce(0, +)
    }
    
    private let appGroupKey = "group.com.ni.StudyTimerAndVideo"
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            // Save to App Group UserDefaults
            if let userDefaults = UserDefaults(suiteName: appGroupKey) {
                userDefaults.set(encoded, forKey: key)
                
                // Save simplified data for Widget (Total Today)
                let todayTotal = totalTime(for: .day)
                userDefaults.set(todayTotal, forKey: "widget_today_total")
                
                // Reload Widget Timeline
                // Note: Requires importing WidgetKit, but doing it safely via KVO or Notification might be better if WidgetKit isn't linked.
                // For now, we just save the data. The widget will refresh based on its timeline or next app open.
            } else {
                // Fallback to standard if App Group fails (though it shouldn't)
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
    
    private func load() {
        // Try loading from App Group first
        let userDefaults = UserDefaults(suiteName: appGroupKey) ?? UserDefaults.standard
        
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LegacyStudySession].self, from: data) {
            sessions = decoded
        }
    }
}

//MARK: - 期間別合計計算を拡張
extension StudyLogManager {
    func totalTime(for period: Calendar.Component, referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        return sessions.filter { session in
            switch period {
            case .day:
                return calendar.isDate(session.date, inSameDayAs: referenceDate)
            case .weekOfYear:
                return calendar.isDate(session.date, equalTo: referenceDate, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(session.date, equalTo: referenceDate, toGranularity: .month)
            case .year:
                return calendar.isDate(session.date, equalTo: referenceDate, toGranularity: .year)
            default:
                return true
            }
        }
        .map { $0.duration }
        .reduce(0, +)
    }
}
