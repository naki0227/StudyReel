import SwiftUI
import SwiftData

//MARK: - 記録を手動で追加
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
    @State private var minutes = 30
    @State private var date = Date()
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 0) {
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
                                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                                }
                                .font(ReelTheme.sans(14))
                                .foregroundColor(ReelTheme.secondary)
                            }
                        }
                        Rectangle().fill(ReelTheme.line).frame(height: 1).padding(.leading, 50)
                        ReelRow(systemImage: "calendar", title: L10n.string("日時")) {
                            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .tint(ReelTheme.accentDeep)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))

                    VStack(alignment: .leading, spacing: 0) {
                        ReelRow(systemImage: "clock", title: L10n.string("勉強した時間")) {
                            Text(hours > 0 ? L10n.format("%d時間%d分", hours, minutes) : L10n.format("%d分", minutes))
                                .font(ReelTheme.sans(14))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        HStack(spacing: 0) {
                            Picker(L10n.string("時間"), selection: $hours) {
                                ForEach(0..<24) { Text(L10n.format("%d時間", $0)).tag($0) }
                            }
                            Picker(L10n.string("分"), selection: $minutes) {
                                ForEach(0..<60) { Text(L10n.format("%d分", $0)).tag($0) }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))

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
                                            if isOn { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
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

                    Text(L10n.string("撮影しなかった日の勉強も、ここから残せます。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            // 見出しは左上に置くと iOS 26 で「…」にまとめられるので、上の真ん中に出す
            .navigationTitle(L10n.string("手動追加"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(L10n.string("閉じる")) { dismiss() }
                            .foregroundColor(ReelTheme.secondary)
                        Button(L10n.string("保存")) { saveManualSession() }
                            .font(ReelTheme.sans(15, weight: .semibold))
                            .foregroundColor(ReelTheme.accentDeep)
                            .disabled(selectedSubject.isEmpty)
                    }
                }
            }
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
