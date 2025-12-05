import SwiftUI
import SwiftData

struct SessionSaveView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject var subjectManager: SubjectManager
    
    @Query private var tags: [Tag]
    @State private var selectedTags: Set<Tag> = []
    @State private var showTagManager = false
    
    @State private var selectedSubject: String = ""
    @State private var duration: Int
    @State private var date: Date = Date()
    
    init(subjectManager: SubjectManager, duration: Int) {
        self.subjectManager = subjectManager
        _duration = State(initialValue: duration)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("教科")) {
                    Picker("教科を選択", selection: $selectedSubject) {
                        ForEach(subjectManager.subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                }
                
                Section(header: Text("時間")) {
                    Text(formatTime(duration))
                        .font(.title2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section(header: HStack {
                    Text("タグ")
                    Spacer()
                    Button("管理") { showTagManager = true }
                        .font(.caption)
                }) {
                    if tags.isEmpty {
                        Text("タグがありません")
                            .foregroundColor(.gray)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags) { tag in
                                    Button(action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill(tag.color)
                                                .frame(width: 10, height: 10)
                                            Text(tag.name)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(selectedTags.contains(tag) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedTags.contains(tag) ? Color.blue : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Button("保存") {
                    let session = StudySession(date: date, duration: duration, subject: selectedSubject, tags: Array(selectedTags))
                    modelContext.insert(session)
                    dismiss()
                }
            }
            .navigationTitle("記録を保存")
            .onAppear {
                if selectedSubject.isEmpty, let first = subjectManager.subjects.first {
                    selectedSubject = first
                }
            }
            .sheet(isPresented: $showTagManager) {
                TagManagerView()
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
