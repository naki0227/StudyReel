import Foundation

//MARK: - 教科管理
class SubjectManager: ObservableObject {
    @Published var subjects: [String] = [] {
        didSet{ save() }
    }
    private let key = "subjects"
    
    init() {
        load()
    }
    
    func add(_ subject: String) {
        guard !subject.isEmpty, !subjects.contains(subject) else { return }
        subjects.append(subject)
    }
    
    func delete(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
    }
    
    private func save() {
        UserDefaults.standard.set(subjects, forKey: key)
    }
    
    private func load() {
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            subjects = saved
        } else {
            subjects = ["数学", "英語", "物理"]
        }
    }
}
