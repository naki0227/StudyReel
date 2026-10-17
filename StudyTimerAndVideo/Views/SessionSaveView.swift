import SwiftUI
import SwiftData

// 録画後の保存画面（タイトル・日付・時間・教科・タグ・メモ）
struct SessionSaveView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager

    @Query private var tags: [Tag]
    @State private var selectedTags: Set<Tag> = []
    @State private var showTagManager = false
    @State private var showSubjectManager = false
    @State private var showDiscardConfirm = false

    @State private var title = ""
    @State private var memo = ""
    @State private var selectedSubject: String = ""
    @State private var duration: Int
    @State private var date: Date = Date()
    @State private var didSave = false

    private let media: SessionMedia

    init(subjectManager: SubjectManager, duration: Int, media: SessionMedia = SessionMedia(), date: Date = Date()) {
        self.subjectManager = subjectManager
        self.media = media
        _duration = State(initialValue: duration)
        _date = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    titleCard
                    detailCard
                    tagCard
                    memoCard
                }
                .padding(16)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("保存しない")) {
                        showDiscardConfirm = true
                    }
                    .foregroundColor(ReelTheme.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("保存")) {
                        save()
                    }
                    .font(ReelTheme.sans(15, weight: .semibold))
                    .foregroundColor(ReelTheme.accentDeep)
                    .disabled(selectedSubject.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .alert(L10n.string("この記録を保存せずに閉じますか？"), isPresented: $showDiscardConfirm) {
                Button(L10n.string("戻る"), role: .cancel) {}
                Button(L10n.string("保存しない"), role: .destructive) {
                    dismiss()
                }
            }
            .onAppear {
                updateDefaultSubject()
            }
            .onDisappear {
                if !didSave {
                    media.discard()
                }
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

    private var titleCard: some View {
        HStack(spacing: 12) {
            SessionThumbnail(fileName: media.thumbnailFileName, subject: selectedSubject)
                .frame(width: 88, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                TextField(L10n.string("タイトル（例：図書館で数学）"), text: $title)
                    .font(ReelTheme.sans(15))
                    .foregroundColor(ReelTheme.ink)
                if !title.isEmpty {
                    Button {
                        title = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ReelTheme.line)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ReelTheme.line, lineWidth: 1)
            )
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private var detailCard: some View {
        VStack(spacing: 0) {
            ReelRow(systemImage: "calendar", title: L10n.string("日時")) {
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(ReelTheme.accentDeep)
            }
            Divider().padding(.leading, 50)
            ReelRow(systemImage: "clock", title: formattedDuration(duration)) {
                EmptyView()
            }
            Divider().padding(.leading, 50)
            ReelRow(systemImage: "book.closed", title: L10n.string("教科")) {
                Menu {
                    ForEach(subjectManager.subjects, id: \.self) { subject in
                        Button(subject) { selectedSubject = subject }
                    }
                    Divider()
                    Button(L10n.string("教科を編集")) { showSubjectManager = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSubject.isEmpty ? L10n.string("選択") : selectedSubject)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.secondary)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ReelRow(systemImage: "tag", title: L10n.string("タグ")) {
                Button(L10n.string("編集")) { showTagManager = true }
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.accentDeep)
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags) { tag in
                            let isOn = selectedTags.contains(tag)
                            Button {
                                if isOn {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                Text("#\(tag.name)")
                                    .font(ReelTheme.sans(12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .foregroundColor(isOn ? ReelTheme.accentDeep : ReelTheme.secondary)
                                    .background(Capsule().fill(isOn ? ReelTheme.accentSoft : ReelTheme.background))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private var memoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(ReelTheme.secondary)
                .frame(width: 22)
                .padding(.top, 2)
            TextField(L10n.string("メモ（任意）"), text: $memo, axis: .vertical)
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.ink)
                .lineLimit(4...10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private func save() {
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = StudySession(
            date: date,
            duration: duration,
            subject: selectedSubject,
            tags: Array(selectedTags),
            recordedAt: Date(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: trimmedMemo.isEmpty ? nil : trimmedMemo,
            thumbnailFileName: media.thumbnailFileName,
            videoFileName: media.videoFileName
        )
        modelContext.insert(session)
        didSave = true
        CloudBackup.markChanged()
        CloudBackup.backupIfNeeded(context: modelContext)
        let updatedSessions = [session] + sessions
        Task {
            await StudyNotificationManager.shared.scheduleQuietReminderIfNeeded(with: updatedSessions)
        }
        dismiss()
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? L10n.format("%d時間%d分", h, m) : L10n.format("%d分", m)
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
