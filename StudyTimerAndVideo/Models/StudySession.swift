import Foundation

//MARK: - 記録保存モデル
struct LegacyStudySession: Codable, Identifiable {
    let id: UUID
    let subject: String
    let duration: Int
    let date: Date
    
    // Custom init to match old struct if needed, or just let memberwise init work
    init(id: UUID = UUID(), subject: String, duration: Int, date: Date) {
        self.id = id
        self.subject = subject
        self.duration = duration
        self.date = date
    }
}
