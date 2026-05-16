import SwiftUI
import SwiftData

struct SessionSaveView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager
    
    @Query private var tags: [Tag]
    @State private var selectedTags: Set<Tag> = []
    @State private var showTagManager = false
    @State private var showSubjectManager = false
    
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
                Section(header: HStack {
                    Text(L10n.string("教科"))
                    Spacer()
                    Button(L10n.string("管理")) { showSubjectManager = true }
                        .font(.caption)
                }) {
                    if !suggestedSubjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedSubjects, id: \.self) { subject in
                                    Button(action: {
                                        selectedSubject = subject
                                    }) {
                                        Text(subject)
                                            .font(.caption)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(selectedSubject == subject ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .foregroundColor(selectedSubject == subject ? .blue : .primary)
                                            .cornerRadius(999)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Picker(L10n.string("教科を選択"), selection: $selectedSubject) {
                        ForEach(subjectManager.subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                }
                
                Section(header: Text(L10n.string("時間"))) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formatTime(duration))
                            .font(.title2)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if let recent = mostRecentSubject {
                            Text(L10n.format("前回は「%@」を勉強していました", recent))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                
                Button(L10n.string("保存")) {
                    let session = StudySession(date: date, duration: duration, subject: selectedSubject, tags: Array(selectedTags), recordedAt: Date())
                    modelContext.insert(session)
                    let updatedSessions = [session] + sessions
                    Task {
                        await StudyNotificationManager.shared.scheduleQuietReminderIfNeeded(with: updatedSessions)
                    }
                    dismiss()
                }
            }
            .navigationTitle(L10n.string("記録を保存"))
            .onAppear {
                updateDefaultSubject()
            }
            .onChange(of: subjectManager.subjects) {
                let subjects = subjectManager.subjects
                guard !subjects.isEmpty else {
                    selectedSubject = ""
                    return
                }
                if !subjects.contains(selectedSubject) {
                    updateDefaultSubject()
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
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private var mostRecentSubject: String? {
        sessions.first?.subject
    }

    private var suggestedSubjects: [String] {
        let sameHourSubjects = sessions
            .filter { Calendar.current.component(.hour, from: $0.date) == Calendar.current.component(.hour, from: date) }
            .map(\.subject)

        let recentSubjects = sessions.prefix(5).map(\.subject)
        let candidates = sameHourSubjects + recentSubjects + [mostRecentSubject].compactMap { $0 }

        var seen = Set<String>()
        return candidates
            .filter { subjectManager.subjects.contains($0) }
            .filter { seen.insert($0).inserted }
            .prefix(4)
            .map { $0 }
    }

    private func updateDefaultSubject() {
        if let recent = mostRecentSubject, subjectManager.subjects.contains(recent) {
            selectedSubject = recent
        } else if let suggested = suggestedSubjects.first {
            selectedSubject = suggested
        } else if let first = subjectManager.subjects.first {
            selectedSubject = first
        }
    }
}
