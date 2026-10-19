import SwiftData
import SwiftUI

// 目標をつくる・直す。新しく作ったときは保存したあと宣言カードを開く
struct GoalEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StudyMaterial> { $0.finishedAt == nil }, sort: \StudyMaterial.createdAt, order: .reverse)
    private var materials: [StudyMaterial]
    @Query(filter: #Predicate<StudyGoal> { $0.archivedAt == nil }) private var activeGoals: [StudyGoal]

    let goal: StudyGoal?
    // 新しく作った目標を渡す（宣言カードを開くため）
    var onCreated: (StudyGoal) -> Void = { _ in }

    @State private var title = ""
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @State private var usesScore = true
    @State private var targetScore = ""
    @State private var maxScore = ""
    @State private var targetHours = ""
    @State private var materialIDs: [UUID] = []
    @State private var note = ""
    @State private var showAchieve = false
    @State private var achievedScore = ""
    @State private var showDelete = false

    private let suggestions = ["TOEIC 800点", "英検2級 合格", "共通テスト 8割", "基本情報 合格"]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TapedPaper(tape: GoalTheme.tapePink, tapeAlignment: .topTrailing, tapeAngle: 5) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                GoalScript(text: "my goal", size: 14)
                                Text(L10n.string("目指すこと"))
                                    .font(ReelTheme.sans(11))
                                    .foregroundColor(ReelTheme.secondary)
                            }
                            TextField(L10n.string("例：TOEIC 800点"), text: $title)
                                .font(ReelTheme.serif(24))
                                .foregroundColor(ReelTheme.ink)
                                .accessibilityIdentifier("goal.title")
                            Rectangle().fill(ReelTheme.line).frame(height: 1)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(suggestions, id: \.self) { item in
                                        Button {
                                            title = L10n.string(item)
                                            applyDefaults(for: item)
                                        } label: {
                                            Text(L10n.string(item))
                                                .font(ReelTheme.sans(11))
                                                .foregroundColor(ReelTheme.secondary)
                                                .padding(.horizontal, 10)
                                                .frame(height: 26)
                                                .background(Capsule().fill(ReelTheme.background))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .accessibilityIdentifier("goal.title.chips")
                        }
                    }
                    .padding(.top, 8)

                    card {
                        row(icon: "calendar", title: L10n.string("期日")) {
                            DatePicker("", selection: $deadline, in: (goal == nil ? Calendar.current.startOfDay(for: Date()) : .distantPast)..., displayedComponents: .date)
                                .labelsHidden()
                            Text(previewDDay)
                                .font(ReelTheme.sans(12, weight: .medium))
                                .foregroundColor(ReelTheme.accentDeep)
                                .monospacedDigit()
                        }
                        divider
                        row(icon: "target", title: L10n.string("点数で目指す")) {
                            Toggle("", isOn: $usesScore).labelsHidden().tint(ReelTheme.accent)
                        }
                        if usesScore {
                            divider
                            row(icon: "", title: L10n.string("目標の点数")) {
                                numberField("800", text: $targetScore, id: "goal.targetScore")
                                Text("/").foregroundColor(ReelTheme.secondary)
                                numberField("990", text: $maxScore, id: "goal.maxScore")
                            }
                        }
                        divider
                        row(icon: "timer", title: L10n.string("目標の勉強時間")) {
                            numberField("300", text: $targetHours, id: "goal.targetHours")
                            Text(L10n.string("時間"))
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.secondary)
                        }
                    }

                    if !materials.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "books.vertical")
                                        .foregroundColor(ReelTheme.secondary)
                                        .frame(width: 22)
                                    Text(L10n.string("使う教材"))
                                        .font(ReelTheme.sans(14))
                                    Spacer()
                                    Text(L10n.format("%d冊", materialIDs.count))
                                        .font(ReelTheme.sans(13))
                                        .foregroundColor(ReelTheme.secondary)
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(materials) { material in
                                            let isOn = materialIDs.contains(material.id)
                                            Button {
                                                if isOn { materialIDs.removeAll { $0 == material.id } } else { materialIDs.append(material.id) }
                                            } label: {
                                                Text(material.name)
                                                    .font(ReelTheme.sans(12))
                                                    .lineLimit(1)
                                                    .foregroundColor(isOn ? ReelTheme.accentDeep : ReelTheme.secondary)
                                                    .padding(.horizontal, 10)
                                                    .frame(height: 28)
                                                    .background(Capsule().fill(isOn ? ReelTheme.accentSoft : ReelTheme.background))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .accessibilityIdentifier("goal.materials.chips")
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.string("ひとこと（カードに出ます）"))
                                .font(ReelTheme.sans(11))
                                .foregroundColor(ReelTheme.secondary)
                            TextField(L10n.string("例：毎朝1時間、寝る前に単語30分。"), text: $note, axis: .vertical)
                                .font(ReelTheme.sans(14))
                                .lineLimit(1...4)
                                .accessibilityIdentifier("goal.note")
                        }
                        .padding(16)
                    }

                    Text(L10n.string("ホームに「D-○」が出ます。目標の点数は、過去問のグラフに線として引かれます。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                        .padding(.horizontal, 4)

                    if goal == nil {
                        Button(action: save) {
                            Text(L10n.string("保存して宣言カードをつくる ✦"))
                                .font(ReelTheme.sans(15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Capsule().fill(canSave ? ReelTheme.accentDeep : ReelTheme.secondary.opacity(0.5)))
                        }
                        .disabled(!canSave)
                        .accessibilityIdentifier("goal.create")
                    } else {
                        editActions
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                // 数字キーボードには閉じるキーがないので「完了」を出す
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.string("完了")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(ReelTheme.sans(15, weight: .semibold))
                }
            }
            .navigationTitle(L10n.string(goal == nil ? "目標をつくる" : "目標"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                        .foregroundColor(ReelTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("保存"), action: save)
                        .disabled(!canSave)
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .onAppear(perform: load)
            .alert(L10n.string("目標を達成しましたか？"), isPresented: $showAchieve) {
                TextField(L10n.string("本番の点数（なくてもOK）"), text: $achievedScore)
                    .keyboardType(.numberPad)
                Button(L10n.string("キャンセル"), role: .cancel) {}
                Button(L10n.string("達成！")) { markAchieved() }
            } message: {
                Text(L10n.string("達成カードを作れるようになります。"))
            }
            .confirmationDialog(L10n.string("この目標を消しますか？"), isPresented: $showDelete, titleVisibility: .visible) {
                Button(L10n.string("目標を消す"), role: .destructive) { deleteGoal() }
            } message: {
                Text(L10n.string("勉強の記録と過去問の点数は消えません。"))
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var editActions: some View {
        VStack(spacing: 10) {
            if goal?.isAchieved == false {
                Button {
                    showAchieve = true
                } label: {
                    Text(L10n.string("達成したことを記録する ✦"))
                        .font(ReelTheme.sans(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
            }
            Button {
                archive()
            } label: {
                Text(L10n.string("この目標を終えて、新しい目標をつくる"))
                    .font(ReelTheme.sans(14, weight: .medium))
                    .foregroundColor(ReelTheme.accentDeep)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Capsule().fill(ReelTheme.accentSoft))
            }
            Button(L10n.string("目標を消す"), role: .destructive) { showDelete = true }
                .font(ReelTheme.sans(13))
                .padding(.top, 4)
        }
    }

    private var previewDDay: String {
        StudyGoal(title: "", deadline: deadline).dDayText()
    }

    private var divider: some View {
        Rectangle().fill(ReelTheme.line).frame(height: 1).padding(.leading, 50)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: ReelTheme.ink.opacity(0.06), radius: 10, y: 6)
            )
    }

    private func row<Trailing: View>(icon: String, title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon.isEmpty ? "circle" : icon)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(ReelTheme.secondary)
                .frame(width: 22)
                .opacity(icon.isEmpty ? 0 : 1)
            Text(title)
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.ink)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private func numberField(_ placeholder: String, text: Binding<String>, id: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(ReelTheme.sans(15))
            .foregroundColor(ReelTheme.accentDeep)
            .frame(width: 64, height: 32)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ReelTheme.background))
            .accessibilityIdentifier(id)
    }

    private func applyDefaults(for suggestion: String) {
        switch suggestion {
        case "TOEIC 800点":
            usesScore = true; targetScore = "800"; maxScore = "990"
        case "共通テスト 8割":
            usesScore = true; targetScore = "720"; maxScore = "900"
        default:
            usesScore = false
        }
    }

    private func load() {
        guard let goal else { return }
        title = goal.title
        deadline = goal.deadline
        usesScore = goal.targetScore != nil
        targetScore = goal.targetScore.map(String.init) ?? ""
        maxScore = goal.maxScore.map(String.init) ?? ""
        targetHours = goal.targetHours.map(String.init) ?? ""
        materialIDs = goal.materialIDs
        note = goal.note
    }

    private func save() {
        guard canSave else { return }
        let target = usesScore ? Int(targetScore) : nil
        let max = usesScore ? Int(maxScore) : nil
        let hours = Int(targetHours).flatMap { $0 > 0 ? $0 : nil }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let goal {
            goal.title = trimmedTitle
            goal.deadline = deadline
            goal.targetScore = target
            goal.maxScore = max
            goal.targetHours = hours
            goal.materialIDs = materialIDs
            goal.note = trimmedNote
            try? modelContext.save()
            CloudBackup.markChanged()
            dismiss()
        } else {
            // 目標はひとつだけ。前の目標は終えたことにする
            for old in activeGoals { old.archivedAt = Date() }
            let created = StudyGoal(
                title: trimmedTitle,
                deadline: deadline,
                targetScore: target,
                maxScore: max,
                targetHours: hours,
                materialIDs: materialIDs,
                note: trimmedNote
            )
            modelContext.insert(created)
            try? modelContext.save()
            CloudBackup.markChanged()
            dismiss()
            onCreated(created)
        }
    }

    private func markAchieved() {
        guard let goal else { return }
        goal.achievedAt = Date()
        goal.achievedScore = Int(achievedScore)
        try? modelContext.save()
        CloudBackup.markChanged()
        dismiss()
    }

    private func archive() {
        goal?.archivedAt = Date()
        try? modelContext.save()
        CloudBackup.markChanged()
        dismiss()
    }

    private func deleteGoal() {
        if let goal { modelContext.delete(goal) }
        try? modelContext.save()
        CloudBackup.markChanged()
        dismiss()
    }
}
