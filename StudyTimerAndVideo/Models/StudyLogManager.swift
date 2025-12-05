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
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
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
