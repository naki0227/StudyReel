import SwiftUI
import SwiftData

//MARK: - 手動追加ビュー
struct ManualAddView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    
    @ObservedObject var subjectManager: SubjectManager
    
    @Query private var tags: [Tag]
    @State private var selectedTags: Set<Tag> = []
    @State private var showTagManager = false
    @State private var showSubjectManager = false
    
    @State private var selectedSubject = ""
    @State private var hours = 0
    @State private var minutes = 0
    @State private var date = Date()
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: HStack {
                    Text(L10n.string("教科"))
                    Spacer()
                    Button(L10n.string("管理")) { showSubjectManager = true }
                        .font(.caption)
                }) {
                    Picker(L10n.string("教科を選択"), selection: $selectedSubject) {
                        ForEach(subjectManager.subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                }
                
                Section(header: Text(L10n.string("時間"))) {
                    HStack {
                        Picker(L10n.string("時間"), selection: $hours) {
                            ForEach(0..<24) { h in
                                Text(L10n.format("%d時間", h)).tag(h)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                        
                        Picker(L10n.string("分"), selection: $minutes) {
                            ForEach(0..<60) { m in
                                Text(L10n.format("%d分", m)).tag(m)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                    }
                }
                
                Section(header: HStack {
                    Text(L10n.string("タグ"))
                    Spacer()
                    Button(L10n.string("管理")) { showTagManager = true }
                        .font(.caption)
                }) {
                    if tags.isEmpty {
                        Text(L10n.string("タグがありません"))
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
                
                Section(header: Text(L10n.string("日付"))) {
                    DatePicker(L10n.string("日付"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Button(L10n.string("保存")) {
                    saveManualSession()
                }
            }
            .navigationTitle(L10n.string("手動追加"))
            .alert(L10n.string("保存できません"), isPresented: $showValidationAlert) {
                Button(L10n.string("OK"), role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                if selectedSubject.isEmpty, let first = subjectManager.subjects.first {
                    selectedSubject = first
                }
            }
            .onChange(of: subjectManager.subjects) {
                let subjects = subjectManager.subjects
                guard !subjects.isEmpty else {
                    selectedSubject = ""
                    return
                }
                if !subjects.contains(selectedSubject) {
                    selectedSubject = subjects[0]
                }
            }
            .sheet(isPresented: $showTagManager) {
                TagManagerView()
            }
            .sheet(isPresented: $showSubjectManager) {
                SubjectEditView(subjectManager: subjectManager)
            }
        }
    }

    private func saveManualSession() {
        let totalSeconds = hours * 3600 + minutes * 60

        guard totalSeconds > 0 else {
            validationMessage = L10n.string("学習時間を1分以上にしてください。")
            showValidationAlert = true
            return
        }

        if let conflict = StudyInsights.overlappingSession(in: sessions, start: date, duration: totalSeconds) {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.timeStyle = .short

            let conflictStart = formatter.string(from: conflict.date)
            let conflictEnd = formatter.string(from: conflict.date.addingTimeInterval(TimeInterval(conflict.duration)))
            validationMessage = L10n.format("この時間帯は「%@」の記録（%@ - %@）と重なっています。", conflict.subject, conflictStart, conflictEnd)
            showValidationAlert = true
            return
        }

        let session = StudySession(
            date: date,
            duration: totalSeconds,
            subject: selectedSubject,
            tags: Array(selectedTags),
            recordedAt: Date()
        )
        modelContext.insert(session)
        let updatedSessions = [session] + sessions
        Task {
            await StudyNotificationManager.shared.scheduleQuietReminderIfNeeded(with: updatedSessions)
        }
        dismiss()
    }
}
