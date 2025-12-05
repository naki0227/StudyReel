import SwiftUI
import SwiftData

//MARK: - 手動追加ビュー
struct ManualAddView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject var subjectManager: SubjectManager
    
    @Query private var tags: [Tag]
    @State private var selectedTags: Set<Tag> = []
    @State private var showTagManager = false
    
    @State private var selectedSubject = ""
    @State private var hours = 0
    @State private var minutes = 0
    @State private var date = Date()
    
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
                    HStack {
                        Picker("時間", selection: $hours) {
                            ForEach(0..<24) { h in
                                Text("\(h)時間").tag(h)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                        
                        Picker("分", selection: $minutes) {
                            ForEach(0..<60) { m in
                                Text("\(m)分").tag(m)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                    }
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
                
                Section(header: Text("日付")) {
                    DatePicker("日付", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Button("保存") {
                    let totalSeconds = hours * 3600 + minutes * 60
                    let session = StudySession(date: date, duration: totalSeconds, subject: selectedSubject, tags: Array(selectedTags))
                    modelContext.insert(session)
                    dismiss()
                }
            }
            .navigationTitle("手動追加")
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
}
